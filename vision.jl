using Base.Threads, Images, Test, Crayons.Box, Serialization

function ensurePwdCorrect()
	@test split(pwd(), "/")[end] == "vision"
end

# MediaMTX setup
function ensureMediaMtx()
	if !isdir("stream/mediamtx") run(`bash setup.sh`) end
	cp("mediamtx.yml", "mediamtx/mediamtx.yml", force=true)
end

(function startUpSelfCheck()
	ensurePwdCorrect()
	ensureMediaMtx()
end)()

# camera code
function cameraThread()

end

