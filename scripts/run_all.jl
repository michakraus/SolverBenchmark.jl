# Run the nonlinear-solver benchmark for every example discussed.
#
#     julia --project=. scripts/run_all.jl
#
# Results (CSV + figures) are written to `results/`, with the time step encoded in
# each file name (e.g. `harmonicoscillator_dt0.1_iterations.png`).

include(joinpath(@__DIR__, "analysis.jl"))

const ANALYSES = [
    # harmonic oscillator and pendulum, at the standard and the coarse time step
    harmonic_oscillator_spec(timespan = (0.0, 100.0), timestep = 0.1),
    harmonic_oscillator_spec(timespan = (0.0, 100.0), timestep = 1.0),
    pendulum_spec(timespan = (0.0, 100.0), timestep = 0.1),
    pendulum_spec(timespan = (0.0, 100.0), timestep = 1.0),
    # Lotka–Volterra systems (iodeproblem) at their native step
    lotka_volterra_2d_spec(),
    lotka_volterra_4d_spec(),
]

for spec in ANALYSES
    run_analysis(spec)
end
