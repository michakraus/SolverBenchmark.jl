include(joinpath(@__DIR__, "nonlinear_analysis.jl"))

# The Toda lattice (N = 16) benchmarked with the NonLinear_OneLayer_GML integrator
# at three time steps, each run for ten steps (so the time span scales with the
# step). This is the highest-dimensional problem in the nonlinear study.
for (timestep, timespan) in ((0.1, (0.0, 1.0)), (1.0, (0.0, 10.0)), (10.0, (0.0, 100.0)))
    run_nonlinear_analysis(toda_lattice_lode_spec(; timestep, timespan))
end
