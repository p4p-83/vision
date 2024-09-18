using Test

# deprecated
function ensurePwdCorrect()
	@test split(pwd(), "/")[end] == "vision"
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