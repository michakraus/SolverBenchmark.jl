# Run every benchmark discussed in the documentation — both the implicit-midpoint
# and the nonlinear-integrator (NonLinear_OneLayer_GML) experiment sets.
#
#     julia --project=. scripts/run_all.jl
#
# Results (CSV + figures) are written to `results/`, with the time step encoded in
# each file name (e.g. `harmonicoscillator_dt0.1_iterations.png`).

include(joinpath(@__DIR__, "midpoint_analysis.jl"))
include(joinpath(@__DIR__, "nonlinear_analysis.jl"))

# --- Implicit midpoint -------------------------------------------------------

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

# --- Nonlinear integrator (NonLinear_OneLayer_GML) ---------------------------
#
# Each nonlinear problem is run for exactly ten steps at three time steps, so the
# time span scales with the step: the larger the step, the harder the implicit
# network solve. The Lotka–Volterra systems are omitted — their degenerate
# Lagrangians are not supported by NonLinear_OneLayer_GML.

const NONLINEAR_STEPS = ((0.1, (0.0, 1.0)), (1.0, (0.0, 10.0)), (10.0, (0.0, 100.0)))

const NONLINEAR_ANALYSES = [
    spec_builder(; timestep, timespan)
    for spec_builder in (harmonic_oscillator_lode_spec, pendulum_lode_spec,
                         double_pendulum_lode_spec, toda_lattice_lode_spec)
    for (timestep, timespan) in NONLINEAR_STEPS
]

# --- Run everything ----------------------------------------------------------

for spec in ANALYSES
    run_analysis(spec)
end

for spec in NONLINEAR_ANALYSES
    run_nonlinear_analysis(spec)
end
