# simple helper file to let you run vision in a standalone fashion
# also doubles as an example of how you can use vision.jl in another .jl file
# see the readme for slightly more info

using Statistics, DataFrames, Crayons.Box

include("vision.jl")
using .Vision

function printCentroidsToStdOut()

	leads, pads = Vision.getCentroids.([2, 1])
	# pads = Vision.getCentroids(1)

	println("\n\n\nLeads" |> BOLD |> GREEN_FG)
	display(DataFrame(reduce(hcat, leads)', ["x", "y"]))
	println("\nPads" |> BOLD |> GREEN_FG)
	display(DataFrame(reduce(hcat, pads)', ["x", "y"]))
	println()

end

#* start
beginVision()

#* keep alive
while true

	Vision.setCompositingMode(Vision.CompositingModes.FROZEN)
	sleep(1)
	
	Vision.setCompositingMode(Vision.CompositingModes.NORMAL)
	sleep(1)

	printCentroidsToStdOut()

end

#* stop
# this won't ever get reached, but it would be good practice to call
# it if at all possible from your code when implementing in future
endVision()