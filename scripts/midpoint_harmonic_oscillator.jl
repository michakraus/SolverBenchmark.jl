# Nonlinear-solver benchmark for the harmonic oscillator.
#
#     julia --project=. scripts/midpoint_harmonic_oscillator.jl

include(joinpath(@__DIR__, "midpoint_analysis.jl"))

run_analysis(harmonic_oscillator_spec(timespan = (0.0, 100.0), timestep = 0.1))
