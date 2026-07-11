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
    # Lotka–Volterra systems (iodeproblem), at the native and a coarse time step
    lotka_volterra_2d_spec(timespan = (0.0, 10.0), timestep = 0.01),
    lotka_volterra_2d_spec(timespan = (0.0, 10.0), timestep = 0.1),
    lotka_volterra_4d_spec(timespan = (0.0, 10.0), timestep = 0.01),
    lotka_volterra_4d_spec(timespan = (0.0, 10.0), timestep = 0.1),
    # double pendulum (hodeproblem), at the standard and the coarse time step
    double_pendulum_spec(timespan = (0.0, 10.0), timestep = 0.01),
    double_pendulum_spec(timespan = (0.0, 10.0), timestep = 0.1),
    # Toda lattice with N = 16 (hodeproblem), at the standard and the coarse time step
    toda_lattice_spec(timespan = (0.0, 100.0), timestep = 0.1),
    toda_lattice_spec(timespan = (0.0, 100.0), timestep = 1.0),
]

for spec in ANALYSES
    run_analysis(spec)
end
