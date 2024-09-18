using Crayons.Box

#* dependencies
include("self-checks.jl")

include("FrameLoop.jl")
import .FrameLoop

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

#* event functions
function atStartup()
	usageNotes()
	ensureMediaMtx()
	@async FrameLoop.frameLoop()
end

function atShutdown()
	FrameLoop.cancelFrameLoop()
end

#* do the startup automatically
atStartup()

while true
	sleep(10)
end

atShutdown()