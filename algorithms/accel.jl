struct Centroid
	x::Cint
	y::Cint
	weight::Cint
end

const cfile::String = "accel"
# const accelDir::String = "$(@__DIR__)"

# compile and dynamically link the C code for use
function accel_compile()

	#!! TODO need to make sure that the compile time constants header is also kept up to date!

	run(`bash -c "cd '$(@__DIR__)'; gcc -std=gnu2x -O3 -c $cfile.c"`)
	run(`bash -c "cd '$(@__DIR__)'; g++ -shared -o $cfile.so $cfile.o -lm -fPIC"`)

end


# perform the compositing to create output frame and also rebuild masks for each camera feed
# takes the outputs as arguments and acts on them in place
# this wrapper calls into the C code
function acceleratedCompositingMaskingLoop!(frameA::Vector{UInt8}, frameB::Vector{UInt8}, frameOut::Vector{UInt8}, maskA::Matrix{UInt8}, maskB::Matrix{UInt8})
	global accel_dl_acceleratedCompositingMaskingLoop

	# @test !isnothing(accel_dl_acceleratedCompositingMaskingLoop)

	@ccall $accel_dl_acceleratedCompositingMaskingLoop(
		frameA::Ptr{UInt8},
		frameB::Ptr{UInt8},
		frameOut::Ptr{UInt8},
		maskA::Ptr{UInt8},
		maskB::Ptr{UInt8}
	)::Cvoid

end

function acceleratedCentroidFinding!(mask::Matrix{UInt8}, centroidList::Vector{Centroid})
	global accel_dl_acceleratedCentroidFinding

	# @test !isnothing(accel_dl_acceleratedCentroidFinding)

	return @ccall $accel_dl_acceleratedCentroidFinding(
		mask::Ptr{UInt8},
		centroidList::Ptr{Centroid}
	)::Cint

end

function mask2frame!(mask::Matrix{UInt8}, frame::Vector{UInt8})
	global accel_dl_mask2frame

	# @test !isnothing(accel_dl_mask2frame)

	@ccall $accel_dl_mask2frame(
		mask::Ptr{UInt8},
		frame::Ptr{UInt8},
	)::Cvoid

end