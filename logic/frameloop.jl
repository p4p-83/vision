#* user settings
const fps::Int = 15											# framerate, s⁻¹
const width::Int = 64*16									# multiples of 64 work best
const height::Int = 64*16

const rtspPort = 8554
const mtxPath = "cm3"

const searchMaxNumCentroids::Int = 200
const searchMaxBuf::Int = 5000
const searchGridStep::Int = 16

const keyingBoardMaskCutInOut::Tuple{Int, Int} = (150, 255)
const keyingComponentMaskCutInOut::Tuple{Int, Int} = (150, 255)

const accelCFileDir::String = "$(@__DIR__)"
const accelCFileName::String = "accel"
const accelCFilePath::String = "$accelCFileDir/$accelCFileName"
const accelLib::String = "$accelCFilePath.so"

#* derived parameters
const samplesLuma::Int = width*height
const samplesChroma::Int = samplesLuma÷4 					# 4:2:2
const samplesPerFrame::Int = samplesLuma + 2samplesChroma 	# YUV

#* commands
const cameraCommands::Vector{Cmd} = [
	`rpicam-vid --flush -t 0 --camera 0 --nopreview --codec yuv420 --framerate $fps --width $width --height $height --inline --listen -o -`
	`rpicam-vid --flush -t 0 --camera 1 --nopreview --codec yuv420 --framerate $fps --width $width --height $height --inline --listen -o -`
]

const ffmpegCommand::Cmd = `ffmpeg -f rawvideo -pix_fmt yuv420p -s:v $(width)x$(height) -i /dev/stdin -c:v libx264 -preset ultrafast -tune zerolatency -fpsmax $fps -f rtsp rtsp://localhost:$rtspPort/$mtxPath`

const mediaMtxCommand::Cmd = `bash -c "cd $accelCFileDir/../stream/mediamtx; ./mediamtx"`

#* control
runFrameLoop::Bool = false
runFrameLoopLock::ReentrantLock = ReentrantLock()

isFreezeFramed::Bool = false
isFreezeFramedLock::ReentrantLock = ReentrantLock()

#* public assets
visionCentroidsPrivate::Vector{Vector{Centroid}} = [fill(Centroid(-1,-1,-1), searchMaxNumCentroids) for _ in cameraCommands]
visionCentroidsLength::Vector{Int} = [0 for _ in cameraCommands]
visionCentroidsLock::ReentrantLock = ReentrantLock()

#* helper functions
function writeCompileTimeConstantsFile()

	location = "$accelCFileDir/accel-compile-time-constants.h"
	content = """
	// AUTOGENERATED by FrameLoop.jl ($(read(`date`, String)|>strip))
	// Do not edit this file directly if you value your sanity...

	// frame size
	#define WIDTH $width
	#define HEIGHT $height

	// masking
	#define MASK_BOARD_CUT_IN $(keyingBoardMaskCutInOut[1])
	#define MASK_COMP_CUT_IN $(keyingComponentMaskCutInOut[1])
	#define MASK_BOARD_CUT_OUT $(keyingBoardMaskCutInOut[2])
	#define MASK_COMP_CUT_OUT $(keyingComponentMaskCutInOut[2])

	// centroids algorithm
	#define MAX_SEARCH_BUF $searchMaxBuf
	#define MAX_NUM_CENTROIDS $searchMaxNumCentroids
	#define GRID_STEP $searchGridStep

	// ENDS"""
	
	write(location, content)

end

function makeAccelerationAvailable()

	writeCompileTimeConstantsFile()
	run(`bash -c "cd '$accelCFileDir'; gcc -std=gnu2x -O3 -c $accelCFileName.c"`)
	run(`bash -c "cd '$accelCFileDir'; g++ -shared -o $accelCFileName.so $accelCFileName.o -lm -fPIC"`)
	
end

#* external functions

# the intention is that you would call this with @async to spawn a thread
function frameLoop()
	global runFrameLoop, runFrameLoopLock
	global visionCentroidsPrivate, visionCentroidsLength, visionCentroidsLock
	global isFreezeFramed, isFreezeFramedLock

	#* ensure there isn't already an instance obviously running
	rfl = @lock runFrameLoopLock runFrameLoop
	if rfl return end
	
	#* preallocate frame buffers and mask buffers
	cameraFrames::Vector{Vector{UInt8}} = [zeros(UInt8, samplesPerFrame) for _ in cameraCommands]
	outputFrame::Vector{UInt8} = zeros(UInt8, samplesPerFrame)
	outputMasks::Vector{Matrix{UInt8}} = [zeros(UInt8, height, width) for _ in cameraCommands] #? BUGS is this the right order height,width?

	#* open resources
	mediamtxIo = open(mediaMtxCommand, "r")
	sleep(0.2)
	cameraIos = open.(cameraCommands, "r")
	ffmpegIo = open(ffmpegCommand, "r+")		# note must be writeable
	write(ffmpegIo, outputFrame)				# no clue, but it bugs out if I don't do this?!?!
	
	sleep(0.2)

	#* repeating loop
	@lock runFrameLoopLock runFrameLoop = true
	while @lock runFrameLoopLock runFrameLoop

		#* read frames into buffers
		readbytes!.(cameraIos, cameraFrames)

		frozen::Bool = @lock isFreezeFramedLock isFreezeFramed

		#* recalculate output frame and masks
		if !frozen # do not modify frame buffers if supposed to be frozen
			# acts in place
			# this function is written in C for speed
			@ccall accelLib.acceleratedCompositingMaskingLoop(
				cameraFrames[1]::Ptr{UInt8},
				cameraFrames[2]::Ptr{UInt8},
				outputFrame::Ptr{UInt8},
				outputMasks[1]::Ptr{UInt8},
				outputMasks[2]::Ptr{UInt8}
			)::Cvoid
		end
		
		#* dispatch composited frame to FFmpeg
		write(ffmpegIo, outputFrame)

		#* use masks to recalculate centroids
		if !frozen # only run if new data will be present
			@lock visionCentroidsLock for i in eachindex(cameraCommands)
				# also in C and also acts in place
				visionCentroidsLength[i] = @ccall accelLib.acceleratedCentroidFinding(
					#! note that this will mangle the outputMasks so cannot be run twice
					outputMasks[i]::Ptr{UInt8},
					visionCentroidsPrivate[i]::Ptr{UInt8}
				)::Cint
			end
		end

	end

	#* close resources
	close(mediamtxIo)
	close.(cameraIos)
	close(cameraIo)

end

function cancelFrameLoop()
	global runFrameLoop, runFrameLoopLock
	@lock runFrameLoopLock runFrameLoop = false
end

function setFreezeFramed(frozen::Bool)
	global isFreezeFramed, isFreezeFramedLock
	@lock isFreezeFramedLock isFreezeFramed = frozen
end

function getCentroids(cameraNumber::Int)::Vector{Centroid}
	global visionCentroidsLock, visionCentroidsPrivate, visionCentroidsLength
	@lock visionCentroidsLock deepcopy(visionCentroidsPrivate[cameraNumber][1:visionCentroidsLength[cameraNumber]])
end

function getCentroidsNorm(cameraNumber::Int)::Vector{Vector{Int}}
	centroids = getCentroids(cameraNumber)
	normFact = 2^16-1
	rows::Vector{Vector{Int}} = [(normFact.*[c.y, c.x]).÷[width, height] for c in centroids]	#! TODO somewhere along the line these must have got inverted — need to fix this back at the root cause
	return rows
end

#* run required initialisation automatically at inclusion
makeAccelerationAvailable()