# Nonlinear-solver benchmark for the 2d Lotka–Volterra system (iodeproblem).
#
#     julia --project=. scripts/lotka_volterra_2d.jl

include(joinpath(@__DIR__, "analysis.jl"))

run_analysis(lotka_volterra_2d_spec())
