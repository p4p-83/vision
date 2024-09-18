# simple helper file to let you run vision in a standalone fashion
# also doubles as an example of how you can use vision.jl in another .jl file
# see the readme for slightly more info

include("vision.jl")
using .Vision

#* start
beginVision()

#* keep alive
while true
	sleep(1)
	display(DataFrame(Pair.(["leads", "pads"], getCentroids())))	# make it easier to see CV results
end

#* stop
# this won't ever get reached, but it would be good practice to call
# it if at all possible from your code when implementing in future
endVision()