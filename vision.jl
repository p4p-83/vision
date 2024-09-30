module Vision
export beginVision, endVision, setCompositingMode, ComposingModes
using Crayons.Box, Base.Threads, FixedPointNumbers

const j::ComplexF64 = im
const °::Float64 = 2π/360	# multiplicative degrees to radians conversion factor
FI16 = Fixed{Int16, 16}

#* dependencies
include("logic/frameloop.jl")

#* internal functions

function usageNotes()
println("""

╒═══════════════════════════════════════════════════════════════════════════╕
│ starting $(" vision.jl " |> GREEN_BG |> WHITE_FG)                                                      │
│                                                                           │
│ This is the master file for all things cameras and computer vision.       │
│   • Vision will begin the live stream as used by the interface.           │
│   • Vision will also begin maintaining CV data as used by the controller. │
│                                                                           │
│ $("Caveats" |> BOLD)                                                                   │
│ You will have to kill this terminal when you're done — this process will  │
│ hold a lock on the camera resources so you will have to make sure this    │
│ process is killed before you can try starting again. (This isn't a biggie │
│ in production, but it is something that you'll have to keep in mind if    │
│ you are trying to run from the REPL.)                                     │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
""")
end

# MediaMTX setup
function ensureMediaMtx()
	prevwd = pwd()
	pathToThisFile = @__DIR__

	cd("$pathToThisFile/stream")
	
	if !isdir("mediamtx") run(`bash setup.sh`) end
	cp("mediamtx.yml", "mediamtx/mediamtx.yml", force=true)
	
	cd(prevwd)
end

#* data extraction functions
# function getCentroids()::Tuple{Vector{Centroid}, Vector{Centroid}}
# 	pads = getCentroids(1)
# 	leads = getCentroids(2)
# 	return (leads, pads)
# end

#* control functions
function beginVision()
	usageNotes()
	ensureMediaMtx()
	@spawn frameLoop()
end

function endVision()
	cancelFrameLoop()
end

end # module Vision