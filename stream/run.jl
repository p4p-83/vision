# run.jl
# 25 Aug '24
# the main application logic for the streaming and (eventually) CV
# sets up MediaMTX and tees the camera data to both CV as desired and FFmpeg

# running this code:
# the main logic of this code is set up to run in a separate thread for dev purposes
# the best way to run this in a testing environment is to load up a REPL session
# and evaluate this code, either with VS Code, with `julia -i run.jl`, or with `include("run.jl")`

# then once you have a REPL with this code as above, you can control things with
# `start()` to kick everything off
# `stop()` to shut down gracefully (note that you may have to type this blindly — there may be stuff getting printed to stderr — but if you don't spell it wrong it will work despite this)

# BUGS for some reason `start()` seems to fail every second time, just like clockwork (FFmpeg error Could not write header for output file #0 (incorrect codec parameters ?): Invalid data found when processing input     Error initializing output stream 0:0 --)
# BUGS running `start()` too soon after `stop()` fails (error seems to be that the RTSP port couldn't be aquired / had yet to be released:     Connection to tcp://localhost:8554?timeout=0 failed: Connection refused       Could not write header for output file #0 (incorrect codec parameters ?): Connection refused      Error initializing output stream 0:0 --)

using Base.Threads, Images, Test, Crayons.Box, Serialization

# you need to cd() the REPL (if using) into vision/stream
# eg `cd("vision/stream")`
@test split(pwd(), "/")[end-1:end] == ["vision", "stream"]

# filesystem setup (replaces run.sh)
if !isdir("mediamtx")
	run(`bash setup.sh`)
end

cp("mediamtx.yml", "mediamtx/mediamtx.yml", force=true)

#* MAIN LOOP AND SUPPORTING CODE
# will run this in its own thread so it's easier to send control signals to stop it
# could just kill it part way through, but this method ensures that the streams always closed
# and therefore you never get 'resource busy' from the camera

# run flag & its lock for thread safety
doMainLoop = false
doMainLoop_lock = ReentrantLock()

# threadsafe function to set the doMainLoop var
function setDoMainLoop(state)
	global doMainLoop, doMainLoop_lock
	lock(doMainLoop_lock) do 
		doMainLoop = state
	end
end

# threadsafe function to read the doMainLoop var
function getDoMainLoop()
	global doMainLoop, doMainLoop_lock
	return lock(doMainLoop_lock) do
		return doMainLoop
	end
end

# function to start the main loop (in a separate thread)
function start()
	@test getDoMainLoop() == false # can't start if already started
	setDoMainLoop(true)
	@async main()
end

# function to stop the main loop (in its separate thread)
stop() = setDoMainLoop(false)

# main loop
# it is recommended that you use `start()` to run in a separate thread so you can `stop()` it (don't call `main()` directly)
function main()

	sleep(1)
	println("Started main loop. (Use `stop()` to stop this in future.)" |> MAGENTA_BG)

	# video settings
	fps::Int = 25							# Hz
	width::Int = 64*16						# ensure this is a multiple of 64
	height::Int = 64*16						# ensure this is a multiple of 64
	# useful constants for post-processing
	bytesPerFrame = Int(width*height*3/2)	# Y channel is width x height; U and V channels are 0.5width x 0.5height
	wh4::Int = (width*height)÷4				# quarter width height product (useful constant for later)
	# see https://forums.raspberrypi.com/viewtopic.php?p=1978205#p1978782 for further explanation

	# camera 1
	camera1Command = `rpicam-vid --flush -t 0 --camera 0 --nopreview --codec yuv420 --framerate $fps --width $width --height $height --inline --listen -o -`

	# FFmpeg
	rtspPort = 8554
	mtxPath = "cm3"
	ffmpegRtspCommand = `ffmpeg -f rawvideo -pix_fmt yuv420p -s:v $(width)x$(height) -i /dev/stdin -c:v libx264 -preset ultrafast -tune zerolatency -fpsmax $fps -f rtsp rtsp://localhost:$rtspPort/$mtxPath`

	# MediaMTX
	mediaMtxCommand = `mediamtx/mediamtx`
	
	# process control objects need to be in this scope
	local ffmpegOutStream, mediaMtxStream, cam1Stream	# forward declare these
	
	try
		
		# spawn required processes
		mediaMtxStream = open(mediaMtxCommand, "r")
		println("started MediaMTX" |> MAGENTA_BG)
		sleep(0.5)											# sleep to let MediaMTX start before we try to get FFmpeg to connect to it
		
		ffmpegOutStream = open(ffmpegRtspCommand, "r+")
		println("started FFmpeg" |> MAGENTA_BG)
		
		cam1Stream = open(camera1Command, "r")
		println("started camera" |> MAGENTA_BG)

		# frame buffer
		rawFrame = zeros(UInt8, bytesPerFrame)				# preallocate a buffer for primary camera's most recent frame

		# spoof stuff
		rawOverlayFrames = deserialize("compositing test file")[2]								# import some test frames so we can see if it works
		overlayLastFrameNumber = length(rawOverlayFrames)										# loop limit
		overlayFrameNumber = 1																	#         … and counter

		uv2yIndexLUT = reshape(1:(4wh4), width, height)[1:2:end, 1:2:end][:]					# LUT to get the y coordinate corresponding to a given u or v coordinate
		y2uvIndexLUT = repeat(reshape(1:(width*height÷2÷2), width÷2, height÷2), inner=[2,2])[:]	# LUT to get the u or v coordinate corresponding to a given y coordinate
		maskY = zeros(Bool, 4wh4)																# pixelwise compositing mask (raw luma channel)
		maskYUV = view(maskY, [1:(4wh4); uv2yIndexLUT; uv2yIndexLUT])							# pixelwise compositing mask (raw format, all channels)

		println("imported overlay" |> MAGENTA_BG)
	
		# the main loop that runs once per frame
		while getDoMainLoop()

			# get a frame (note that this is **blocking**)
			readbytes!(cam1Stream, rawFrame)

			# composite in place
			#? probably I should do all of this in the same C code that processes centroids? Could only speed things up
			maskY .= .!(rawOverlayFrames[overlayFrameNumber][1:(4wh4)] .== 16)			# update maskY (maskYUV uses same underlying values)
																						# NOTE THAT THAT BROADCASTING DOT (i.e.	`maskY .= `, NOT `maskY = `)
																						# IS ABSOLUTELY ESSENTIAL FOR CORRECT OPERATION

			rawFrame[maskYUV] = rawOverlayFrames[overlayFrameNumber][maskYUV]			# composite within mask

			overlayFrameNumber += 1														# advance to next frame for the next frame of underlying video
			if overlayFrameNumber > overlayLastFrameNumber overlayFrameNumber = 1 end

			# "pipe" frame to FFmpeg
			write(ffmpegOutStream, rawFrame)											# frames sent here end up at the web front end

			# do CV processing on frame
			# Could either do this synchronously (to this thread) by calling into the processing function.
			# If this doesn't delay the following thread too much then that CV process can pass the computed output data
			# to a separate logic thread using a Channel (see `help?> Channel`).
			# That or we just `deepcopy(…` the raw frame into a threadsafe secondary buffer and then let all of the CV happen
			# in another thread.
			# I'm not sure at this point which of these options is most favourable. Probably we just pick one and
			# see how it goes, but at any rate, this is the place to put the first bit of logic:
			# TODO
			#? maybe this is where I just directly call into my centroids finding C code?
			# then put the output of that down the channel?

			# sleep for a bit
			# do this if other threads need locked resources (because readbytes! busy waits)
			#! don't think this is actually necessary with the code in its present state — no resources to coordinate
			# sleep(1/fps/8) 	# one eighth of frame period (1 sec / fps / fraction)
							# don't want this too small, lest the other threads struggle to line up a lock
							# don't want this too big, as we may on occasion need to pipe / process multiple frames
							# 	in one camera frame period in order to catch up (if we somehow fall behind)

		end

		println("Got stop signal. Closing up." |> MAGENTA_BG)

	catch err
		# need to do this otherwise all errors within the try block go magically invisble, which isn't particularly helpful
		println("got error $err")

	finally
		# always close all 3 streams even if the try code above errors
		# wrap in further try/catches to ensure that one failed close operation doesn't stop any other subsequent ones
		try close(cam1Stream); 		println("closed camera" |> MAGENTA_BG) 		catch err @warn "couldn't close camera stream (err $err)" 		end
		try close(ffmpegOutStream); println("closed FFmpeg" |> MAGENTA_BG) 		catch err @warn "couldn't close FFmpeg instance (err $err)" 	end	
		try close(mediaMtxStream); 	println("closed MediaMTX" |> MAGENTA_BG) 	catch err @warn "couldn't close MediaMTX instance (err $err)" 	end
	end

	println("All done. Main loop out. Use `start()` if you wish to begin again." |> MAGENTA_BG)

end

# @async (function notes()
(function notes()
	sleep(0.25)
	println("\n\nrun `start()` when you're ready to start streaming." |> GREEN_FG)
	println("run `stop()` to wrap up and stop streaming")
	println("use `exit()` to close the Julia session (don't do this before you've stopped the stream.)\n")
	println("note that this code is multithreaded, and you currently have $(n=nthreads()) thread$(n==1 ? "" : "s") allocated to Julia. You can change this with $("export JULIA_NUM_THREADS=2" |> ITALICS) in the shell (before opening the REPL) or by setting $("\"julia.NumThreads\": 2" |> ITALICS) in the host machine's VS Code settings.json.")
end)()