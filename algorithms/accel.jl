using Libdl, Images, Random, BenchmarkTools

function makeMask()
	Random.seed!(1)
	w = 1000
	h = 1000
	m = rand(Float64, h, w)
	mask = colorview(Gray, m)
	mask2 = imfilter(mask, Kernel.gaussian(20))
	mask3 = colorview(Gray, [x .> 0.51 ? 1.0 : 0.0 for x in mask2])
	return Cint.(channelview(mask3))
end

struct Centroid
	x::Cint
	y::Cint
	weight::Cint
end

function main()
	cfile = "accel"
	run(`gcc -std=gnu2x -O3 -c $cfile.c`)
	run(`g++ -shared -o $cfile.so $cfile.o -lm -fPIC`)
	centroids = Libdl.dlopen("./$cfile.so") do ccode
		
		function findPads(mat::Matrix{Cint})::Vector{Centroid}
			(height, width) = size(mat)
			matPtr = pointer(mat)
			centroidsList = fill(Centroid(0, 0, 0), 200)
			centroidsListPtr = pointer(centroidsList)
			numCentroids = GC.@preserve centroidsList @ccall $(Libdl.dlsym(ccode, :findPads))(width::Cint, height::Cint, matPtr::Ptr{Cint}, centroidsListPtr::Ptr{Centroid})::Cint
			return centroidsList[1:numCentroids]
		end

		mask = makeMask()
		centroids = GC.@preserve mask findPads(mask)
		display(@benchmark $findPads($mask))

		preview = [px > 0 ? RGB(1, 1, 1) : RGB(0.9, 0.9, 0.9) for px in mask]
		for c in centroids preview[c.y, c.x] = RGB(0, 0, 0) end
		display(preview)

		return centroids

	end
	return centroids
end

centroids = main()





function acceleratedCompositingMaskingLoop(frameA, frameB)

	return (frameOut, maskA, maskB)
end

function acceleratedCentroidFinding(mask)
	return centroids
end