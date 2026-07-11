# Nonlinear-solver benchmark for the double pendulum.
#
#     julia --project=. scripts/double_pendulum.jl

include(joinpath(@__DIR__, "analysis.jl"))

run_analysis(double_pendulum_spec(timespan = (0.0, 10.0), timestep = 0.01))
