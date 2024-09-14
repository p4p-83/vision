#!/bin/bash

# NOTE
echo "run.sh is no longer supported!"
# run.sh will no longer work as expected as the MediaMTX config no longer
# starts the camera or FFmpeg at init.

# Please use run.jl instead. The most direct way to do this at the command line
# is with `julia -i run.jl` to load it into a REPL session, and then `julia> start()`
# to actually begin streaming. (You can then use `stop()` to stop it cleanly.)

set -e

if [ ! -d mediamtx ]; then
	./setup.sh
fi

cp mediamtx.yml mediamtx/
cd mediamtx
./mediamtx
