# CV Algorithms
# These turn centroids into machine moves

using Plots, Statistics
default( fontfamily="LinLibertine_Rah", size=(720, 720), label="", background_color="#fffe", background_color_inside=:transparent, foreground_color="#777", dpi=300 )

j = im
° = 2π/360	# multiplicative degrees to radians conversion factor

struct MachineMovement
	translation::ComplexF64		# pixels, presumably — TODO standardise
	rotation::Float64			# radians
end

function alignRotation(leads, pads ; choice=1, referenceLeadIndex=1, resolution=3°, selectivity=5, plotting=false)
	# leads is a list of the lead centroids
	# pads is a list of the pad centroids
	
	reference = leads[1]
	pads .-= reference
	leads .-= reference

	if plotting
		scatter(pads, color=:lightgreen, xlims=(-5, 5), ylims=(-5, 5), label="pads")
		scatter!(leads, color=:magenta, label="leads") |> display
	end

	binSize = resolution
	numBins = 360°/binSize |> round |> Int
	binSize = 360°/numBins
	binLabels = binSize .* ((1:numBins) .- 0.5)
	bins = zeros(Float64, numBins)

	leadCoords = [(abs(l), angle(l)) for l in leads]

	for p in pads

		rp = abs(p)
		φp = angle(p)
	
		# see which arg bands it might touch
		for (rl, φl) in leadCoords[2:end]
	
			# calculate the quality of the match
			radiusMismatch = rl - rp
			quality = sech(selectivity*radiusMismatch)
	
			# calculate the angle required for this match
			angle = φl - φp
			while angle < 0° angle += 360° end
			while angle >= 360° angle -= 360° end

			if plotting
				println("quality of $quality at angle $(φp/1°)°")
			end
	
			# find the relevant bin
			binNum = 1 + (angle/binSize |> floor |> Int)
	
			# store in the bin
			bins[binNum] += quality
	
		end
	
	end
	
	binOrdering = sortperm(bins, rev=true)
	rankedAngles = binLabels[binOrdering]
	
	chosenCorrection = rankedAngles[choice]

	if plotting
		bar(binLabels/1°, bins,
			color=:lightblue,
			xlabel="rotation being considered, °rees",
			ylabel="favourability, relative",
			title="Plot showing relative quality of all possible rotational corrections",
		) |> display

		newPads = pads .* exp(j*chosenCorrection)

		scatter(leads, color=:magenta, label="leads")
		scatter!(newPads, color=:lightgreen, xlims=(-5, 5), ylims=(-5, 5), label="pads (best fit)") |> display
	end

	return MachineMovement(0+0j, chosenCorrection)

end

function wick(leads, pads ; plotting=false)

	if plotting
		scatter(pads, markershape=:square, color=:black, label="pads", title="Initial conditions with analysis")
		scatter!(leads, xlims=(-15, 15), ylims=(-15, 15), markershape=:cross, color=:magenta, label="leads")
	end

	# STEP 0 — PREPARATION
	# find corresponding pad for each lead
	mapping = []
	for l in leads
		deltas = abs.(pads .- l)
		push!(mapping, argmin(deltas))
	end

	# variables to keep track of the movements we make (so we can apply them to the machine)
	trackedTranslation::ComplexF64 = 0	# all of this applied to the pads
	trackedRotation::Float64 = 0	# all of this applied to the leads

	# STEP 1 — REMOVE NET TRANSLATION
	# step 2 requires this gone first
	movements = pads[mapping].-leads
	meanMovement = mean(movements)
	pads .-= meanMovement
	trackedTranslation += meanMovement

	if plotting
		quiver!(leads, quiver=reim.(movements), color=:magenta)
		quiver!([0+0j], quiver=[reim(meanMovement)]) |> display
	end

	movements = leads.-pads[mapping]
	meanMovement = mean(movements)

	# STEP 2 — REMOVE ROTATION
	# no translational error on pads at present, so we can use them to calculate the centre of rotation
	centreOfRotation = mean(pads[mapping])

	if plotting
		scatter(pads, markershape=:square, color=:black, label="pads", title="After correcting net translation")
		scatter!(leads, xlims=(-15, 15), ylims=(-15, 15), markershape=:cross, color=:magenta, label="leads")
		quiver!(leads, quiver=reim.(-movements), color=:magenta)
		quiver!([0+0j], quiver=[reim(meanMovement)])
		scatter!([centreOfRotation], label="centre of residual rotation", markershape=:xcross, color="darkgreen") |> display
	end

	# calculate rotational correction
	subtendedAngles = angle.(pads[mapping].-centreOfRotation) .- angle.(leads.-centreOfRotation)
	meanRotation = mean(subtendedAngles)

	# if the desired centre of rotation isn't the actual centre of rotation of the nozzle, it will move
	# calculate the required translation to "catch" it
	#* technically I could've just done another net translation calculation correction step to acheive the same effect…
	correctiveTranslation = centreOfRotation*(1-cis(meanRotation))

	# make these corrections
	leads .*= cis(meanRotation)
	trackedRotation += meanRotation
	pads .-= correctiveTranslation
	trackedTranslation += correctiveTranslation

	if plotting
		residualErrors = pads[mapping].-leads
		meanResidError = mean(residualErrors) |> abs
		maxResidError = max(abs.(residualErrors)...)
		println("translated $trackedTranslation")
		println("rotated $(trackedRotation/1°)°")
		println("mean residual error $meanResidError")
		println("max residual error $maxResidError")
		scatter(pads, markershape=:square, color=:black, label="pads", title="After all corrections")
		scatter!(leads, xlims=(-15, 15), ylims=(-15, 15), markershape=:cross, color=:magenta, label="leads")
		quiver!(leads, quiver=reim.(residualErrors), color=:magenta)
		quiver!([0+0j], quiver=[reim(meanResidError)]) |> display
		# @test maxResidError < 2e-15
	end

	return MachineMovement(trackedTranslation, trackedRotation)
	
end