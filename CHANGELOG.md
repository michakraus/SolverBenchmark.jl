# Changelog

All notable changes to SolverBenchmark.jl are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-08-08

Upgrade to the current Geometric* stack.

### Changed

- **Dependencies**: GeometricIntegrators 0.17, GeometricIntegratorsBase 0.5.1,
  SimpleSolvers 0.10.1, GeometricProblems 0.8 (which pulls EulerLagrange 0.5).
  Requires NonlinearIntegrators with compat for that stack.
- **`max_stalls = 5`** for every solve, against a SimpleSolvers default of 2. The
  near-singular network solves of the nonlinear experiment set trip two consecutive
  non-moving steps while still making progress.
- **`quiet = true` filters instead of muffling.** It installs a logger that drops
  records from GeometricIntegratorsBase and SimpleSolvers, rather than wrapping each
  run in a `NullLogger`. `verbosity = 0` now silences the benchmarked solver on its
  own; what remains unreachable is `HermiteExtrapolation`'s "history identical"
  warning and the inner `integrate(tem_ode, ImplicitMidpoint())` that
  `NonLinear_OneLayer_GML` runs per step with no options. Warnings from anywhere
  else now reach documentation builds.
- **`_solver_options` states only what it overrides.** GeometricIntegratorsBase 0.5
  merges options over `default_options(method, problem)` instead of replacing them,
  so `min_iterations = 1` no longer needs restating. The framework `f_abstol`
  default is now `max(8, solversize(method, problem)) * eps(T)`; it evaluates to
  `8 eps(T)` for every problem benchmarked here, so no `f_abstol_factor` changed.
- Maintainer notes moved from `memory.md` to `CLAUDE.md`, and the historical
  material in them became this changelog. Comments and documentation now describe
  the package as it is; how it got there is recorded here.

### Fixed

- The documentation index listed four implicit-midpoint analyses; the site builds
  six. Double Pendulum and Toda Lattice were missing.
- The index claimed every problem is integrated over `(0, 100)` at `Δt = 0.1`;
  Lotka–Volterra and the double pendulum use `(0, 10)` at `Δt = 0.01`, and every
  problem also runs at a ten times coarser step.
- Maintainer notes referred to a `_typed_parameters` helper that no longer exists,
  to `scripts/analysis.jl` (since split into `midpoint_analysis.jl` and
  `nonlinear_analysis.jl`), and to `julia = "1.10"` where the project requires 1.11.
  `scripts/nonlinear_analysis.jl` carried the same stale filename.
- `src/nonlinear.jl` described the network integrator as seeding with `OGA1d`; the
  harness default is `OGA1d_Legacy`.

## [0.1.0] — 2026-07-14

Initial benchmark harness.

### Added

- Problem-/integrator-agnostic harness: `ProblemSpec`, `SolverConfig`,
  `InitialGuessConfig`, and `run_case`/`run_benchmark` returning a `DataFrame` of
  convergence, iterations per step, runtime, residual, energy drift and accuracy.
  Because `integrate` does not return solver statistics, runs are driven one step at
  a time so `SimpleSolvers.iteration_number`/`residuals` can be read per step.
- Sweep of precision (`Float16`/`Float32`/`Float64`) × solver (`Newton` with the
  `Static`, `Backtracking`, `Bisection`, `Quadratic`, `BierlaireQuadratic` and
  `StrongWolfe` line searches, plus `DogLeg` and `Picard`) × initial guess
  (`HermiteExtrapolation`, `MidpointExtrapolation`, `NoInitialGuess`) — 72 runs per
  problem, each also at a ten times coarser time step.
- Examples: harmonic oscillator and pendulum (`odeproblem`), Lotka–Volterra 2d and
  4d (`iodeproblem`), double pendulum and Toda lattice with `N = 16` (`hodeproblem`).
- Second experiment set: the neural-network variational integrator
  `NonLinear_OneLayer_GML` from NonlinearIntegrators.jl, sweeping the solver's
  `regularization_factor` `λ ∈ {0, 1e-3, 1e-5, 1e-7}` in place of the initial guess,
  over LODE forms of the oscillator, pendulum, double pendulum and Toda lattice at
  `Δt = 0.1`, `1.0` and `10.0`.
- `relu_k`/`gelu`/`elu` activation factories and configurable `activation` /
  `initial_guess_method` on `nonlinear_onelayer_method`, with the standalone
  `scripts/nonlinear_activation_study.jl` comparing activations against the ReLU
  baseline under both OGA seeds.
- CairoMakie plot helpers (`plot_convergence`, `plot_iterations`, `plot_runtime`,
  `plot_energy_drift`, `plot_accuracy`, `comparison_figure`) and `summary_table` /
  `markdown_table`.
- Driver scripts per example plus `run_all.jl`, writing CSV and figures to a
  gitignored `results/` with the time step encoded in each file name.
- Documenter site regenerating every table and figure at build time, and a test
  suite covering the ODE, IODE, HODE and network-integrator paths.

### Changed

- `f_abstol_factor` on `ProblemSpec`, set to 256 for the double pendulum, the Toda
  lattice and the LODE specs, whose residual floors sit well above `8 eps(T)`.
- `max_iterations` capped at 100 for the implicit-midpoint sweep so divergent
  configurations give up quickly.
- Plot and table ordering of the initial guesses fixed to
  `NoInitialGuess` → `HermiteExtrapolation` → `MidpointExtrapolation`, independent of
  the benchmark's row order.
- Implicit-midpoint driver scripts prefixed `midpoint_`, and `run_all.jl` extended to
  cover both experiment sets.

### Fixed

- CI matrix uses the runners' native macOS arch and released Julia versions.
