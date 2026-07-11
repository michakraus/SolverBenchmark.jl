# Nonlinear-solver benchmark for the mathematical pendulum.
#
#     julia --project=. scripts/pendulum.jl

include(joinpath(@__DIR__, "analysis.jl"))

run_analysis(pendulum_spec(timespan = (0.0, 100.0), timestep = 0.1))
