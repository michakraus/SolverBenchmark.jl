# Nonlinear-solver benchmark for the Toda lattice (N = 16).
#
#     julia --project=. scripts/toda_lattice.jl

include(joinpath(@__DIR__, "analysis.jl"))

run_analysis(toda_lattice_spec(timespan = (0.0, 100.0), timestep = 0.1))
