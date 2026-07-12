include(joinpath(@__DIR__, "nonlinear_analysis.jl"))

# The pendulum benchmarked with the NonLinear_OneLayer_GML integrator at three
# time steps, each run for ten steps (so the time span scales with the step).
for (timestep, timespan) in ((0.1, (0.0, 1.0)), (1.0, (0.0, 10.0)), (10.0, (0.0, 100.0)))
    run_nonlinear_analysis(pendulum_lode_spec(; timestep, timespan))
end
