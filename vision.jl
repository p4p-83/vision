using Base.Threads, Images, Test, Crayons.Box, Serialization

@test split(pwd(), "/")[end] == "vision"

# MediaMTX setup
if !isdir("stream/mediamtx") run(`bash setup.sh`) end
cp("mediamtx.yml", "mediamtx/mediamtx.yml", force=true)

# camera code
function cameraThread()

end

