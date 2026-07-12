include(joinpath(@__DIR__, "nonlinear_analysis.jl"))

# The NonLinear_OneLayer_GML integrator is benchmarked at three time steps, each
# run for exactly ten steps (so the time span scales with the step): the larger
# the step, the harder the implicit network solve.
for (timestep, timespan) in ((0.1, (0.0, 1.0)), (1.0, (0.0, 10.0)), (10.0, (0.0, 100.0)))
    run_nonlinear_analysis(harmonic_oscillator_lode_spec(; timestep, timespan))
end
