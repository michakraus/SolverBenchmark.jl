# Nonlinear-solver benchmark for the 4d Lotka–Volterra system (iodeproblem).
#
#     julia --project=. scripts/midpoint_lotka_volterra_4d.jl

include(joinpath(@__DIR__, "midpoint_analysis.jl"))

run_analysis(lotka_volterra_4d_spec())
