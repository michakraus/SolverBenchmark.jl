# Changelog

All notable changes to SolverBenchmark.jl are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`BFloat16` is swept alongside `Float16`.** `default_precisions()` is now
  `(BFloat16, Float16, Float32, Float64)`, so both experiment sets grow by a
  quarter (96 runs per implicit-midpoint problem, 64 per nonlinear problem). The
  two 16-bit formats divide their bits differently — `Float16` has 11 significand
  bits and a 5-bit exponent, `BFloat16` 8 and 8 — so sweeping both separates a
  failure caused by too few digits from one caused by too little dynamic range.
  `BFloat16` is re-exported, so callers need no direct BFloat16s dependency.
- `precision_label(T)`, the name written to the `precision` column. It uses
  `nameof` rather than `string`, which renders a type module-qualified when its
  module is not visible from `Main` — `string(BFloat16)` gives
  `"BFloat16s.BFloat16"` inside a Documenter `@example` sandbox, and the plotting
  code drops rows whose precision label it does not recognise.
- `scripts/f_abstol_study.jl`, comparing the relaxed `f_abstol_factor = 256`
  against the framework default for the specs that override it.
- `RegularizationConfig`, `scaled_regularization` and `regularization_exponent`:
  the nonlinear sweep's `regularization_factor` is now a function of the working
  precision rather than a number. Nonlinear rows carry the exponent and the value
  each one resolved to in `regularization_exponent`/`regularization_factor`.
- `cached_sweep`/`sweep_cache_dir`, and a `DOCS_PAGES` knob on `docs/make.jl`: the
  documentation build now fans out over one CI job per analysis page, each computing
  only that page's sweeps and passing the results to the job that renders the site.
  Without a cache directory configured it is a plain call, so a local
  `julia --project=docs docs/make.jl` behaves exactly as before.
- `_REGULARIZATION_ORDER` and `_PANEL_ORDER` in `src/plots.jl`, so the nonlinear
  panels have an explicit display order instead of relying on `λ` being the
  innermost loop. `_PANEL_ORDER` covers both experiment sets, so no call site has to
  name the order it wants.

### Changed

- **The nonlinear sweep's regularization is scaled to the precision.** It ran
  `λ ∈ {0, 1e-3, 1e-5, 1e-7}`; all three nonzero values are far below `√eps(T)` at
  anything but `Float64`, so they could not lift a near-singular Jacobian in reduced
  precision and the sweep could not distinguish "λ too small" from "precision too
  low". It now runs the `λ = 0` control plus six rungs of `2^k √eps(T)` —
  `k = 1…6` at `BFloat16`/`Float16`/`Float32`, `k = 2, 4, …, 12` at `Float64`, both
  ladders containing NonlinearIntegrators' recommended `16√eps(T)`. 112 runs per
  nonlinear problem, up from 64. Panels are labelled by rung, because the value
  behind a rung differs by precision while a `DataFrame` holds all four.
  Measured, this removes the confound without changing the verdict: the
  reduced-precision runs fail in the OGA initial guess, not in the Newton solve
  `regularization_factor` acts on — see `docs/src/findings.md`.

- **The Toda lattice uses the framework's default residual tolerance again.** Its
  `f_abstol_factor = 256` was re-measured against the alternative: it bought 3
  converged runs of 96 at `Δt = 0.1` and 1 at `Δt = 1.0`, while costing one to two
  orders of magnitude of residual on every run that converged either way (`Float64`
  worst case `1.8e-15` → `5.7e-14`). Unlike the double pendulum, the Toda lattice
  has no raised residual floor. The double pendulum and the four LODE specs keep
  their overrides, which the same measurement shows are still load-bearing.
- **The documentation is built by one workflow, not two.** `CI.yml` no longer carries a
  `Documentation` job: it duplicated the whole build and raced
  `.github/workflows/Documenter.yml` for the `gh-pages` branch. That workflow now runs a
  `sweep` matrix of ten jobs — one per analysis page — followed by a `documenter` job
  that collects their results, renders the site and deploys, and withholds the
  deployment when any sweep failed. `makedocs` is called with `pagesonly=true`, without
  which each `sweep` job would expand every page and run the entire study.
- Benchmark rows carry the `f_abstol` each run was solved to, and `summary_table`
  adds an `at_tolerance` column marking converged rows whose `max_residual` is
  within a factor of ten of it — so "converged against a target too loose to be
  informative" travels with the data. The column is omitted when no row is flagged.
  It is what makes the `BFloat16` double pendulum legible: residual 1.2–1.5 against
  `256 eps(BFloat16) = 2.0`, on a system whose energy is `O(1)`.
- `run_nonlinear_benchmark` builds the integrator once per precision *inside* an
  error handler. A precision whose network cannot be constructed is now recorded
  as non-converged rows instead of aborting the whole sweep.
- `plot_convergence` scales its figure height with the number of precisions
  instead of hard-coding one that fitted three rows.

### Fixed

- **A `BFloat16` compatibility layer** (`src/bfloat16.jl`). The stack does not
  support `BFloat16` out of the box, and because `run_case`/`run_nonlinear_case`
  record any exception as a non-converged row, each gap first presented as a
  numerical failure rather than a missing method. All are upstream gaps, all use
  the same exact widen-to-`Float32`-and-round, and all should be dropped as
  BFloat16s and NaNMath grow the methods:
  - `Base.rem` and `Base.Integer`, needed by the generic `AbstractFloat` range
    constructor that builds every solution's `TimeSeries`. Without them every run
    fails.
  - `Base.sincos`, which otherwise **recurses until the stack overflows**:
    `sincos(x) = _sincos(float(x))` and `_sincos(x::AbstractFloat) = sincos(x)`.
  - `Base.atan(y, x)`, `Base.fma` and `Base.mod2pi`.
  - `NaNMath.{sin,cos,tan,asin,acos,atanh,acosh,log,log2,log10,log1p}`, whose
    NaN-returning variants are declared for `Union{Float16,Float32,Float64}` only
    while GeometricProblems writes its right-hand sides against them. Adds a direct
    `NaNMath` dependency.

  With the layer in place all six implicit-midpoint problems converge at
  `BFloat16`; without the NaNMath part, four of them appeared not to.

## [0.2.0] — 2026-08-08

Upgrade to the current Geometric* stack.

### Changed

- **Dependencies**: GeometricIntegrators 0.17, GeometricIntegratorsBase 0.5.1,
  SimpleSolvers 0.10.1, GeometricProblems 0.8 (which pulls EulerLagrange 0.5).
  Requires NonlinearIntegrators 0.2.
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
