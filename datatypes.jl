struct Centroid
	x::Cint
	y::Cint
	weight::Cint
end

struct MachineMovement
	translation::ComplexF64		# pixels, presumably — TODO standardise
	rotation::Float64			# radians
end