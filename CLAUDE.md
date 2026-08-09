# Maintainer notes

Internal notes for developing and extending SolverBenchmark.jl. User-facing usage
lives in `README.md` and the
[documentation](https://michakraus.github.io/SolverBenchmark.jl/dev/); the release
history lives in `CHANGELOG.md`. This file describes the package as it is now — put
anything about how it got that way in the changelog.

## What this package does

Benchmarks the nonlinear solvers of **SimpleSolvers.jl** (`Newton` with six line
searches, `DogLeg`, `Picard`) as used inside implicit integrators, on example
problems from **GeometricProblems.jl**. Every run records convergence,
iterations/step, runtime, residual, energy drift and — where an analytic solution
exists — accuracy. Two experiment sets:

1. **Implicit midpoint**, sweeping precision (`Float16/32/64`) × solver × line
   search × initial guess (72 runs per problem).
2. **`NonLinear_OneLayer_GML`** from NonlinearIntegrators.jl, sweeping precision ×
   a reduced solver set × the solver's `regularization_factor` (48 runs).

The harness is problem-/integrator-agnostic so new examples and integrators can be
added easily.

## Code map

- `src/problems.jl` — `ProblemSpec` and the implicit-midpoint specs. HO/Pendulum use
  `odeproblem`, Lotka–Volterra 2d/4d `iodeproblem`, double pendulum and Toda lattice
  (N = 16) `hodeproblem`.
- `src/nonlinear.jl` — the second experiment set: LODE specs, activation factories
  (`relu_k`/`gelu`/`elu`), `nonlinear_onelayer_method`, `run_nonlinear_case`/
  `run_nonlinear_benchmark`.
- `src/configurations.jl` — `SolverConfig`/`InitialGuessConfig` and the default grid.
- `src/benchmark.jl` — solver options, the `quiet` logger, `run_case`/`run_benchmark`
  (returns a `DataFrame`).
- `src/plots.jl` — CairoMakie plot helpers, `summary_table`, `markdown_table`.
- `scripts/` — `midpoint_analysis.jl`/`nonlinear_analysis.jl` shared runners, one
  script per example, `run_all.jl` (everything in the docs) and the standalone
  `nonlinear_activation_study.jl`. Write CSV + figures to `results/` (gitignored);
  file names embed Δt.
- `docs/` — Documenter site; analysis pages regenerate figures via `@example`
  (`timing=:quick, quiet=true`).

## Non-obvious facts / gotchas

- **Solver stats are not returned by `integrate`.** `run_case` drives the integrator
  step-by-step (`GeometricIntegratorsBase.solutionstep`/`solverstate`, not
  re-exported → `import GeometricIntegratorsBase as GIB`; `GIB.current` must be
  qualified) to read `SimpleSolvers.iteration_number`/`residuals` per step.
- **`DogLeg`/`Picard` reject the `linesearch` keyword** — only `Newton` accepts it.
- **Line-search constructors are precision-typed** (`Backtracking(T)` etc.). Problem
  constructors take no `::Type{T}` argument, so precision comes from the `q₀`/`p₀`
  element type — pass `parameters = Module.default_parameters(T)` as well, or the
  parameters stay `Float64` and the run mixes precisions.
- **The "Solver took N iterations" warning is gated by `warn_iterations`, not
  `verbosity`.** The harness sets both to 0.
- **Solver options are merged over `default_options(method, problem)`**, so
  `_solver_options` lists only what it changes. The framework `f_abstol` default is
  `max(8, solversize(method, problem)) * eps(T)`, which is `8 eps(T)` for every
  problem here (`solversize ≤ 8`), so `f_abstol_factor` is measured against that.
- **`quiet=true` installs `_QuietLogger`, not a `NullLogger`.** `verbosity = 0`
  silences the benchmarked solver completely, so the filter only has to drop two
  sources no solver option reaches: GIB's `HermiteExtrapolation` "history identical"
  warning (its `nowarn` kwarg is not threaded through `GeometricIntegrator`), and
  the inner `integrate(tem_ode, ImplicitMidpoint())` that `NonLinear_OneLayer_GML`
  runs per step for its `IntegratorExtrapolation` seed — called with no options, so
  it uses SimpleSolvers' defaults (`verbosity=1`, `warn_iterations=1000`,
  `Backtracking`) no matter how the outer solver is configured. Forwarding options
  to that inner call upstream would let `quiet` be retired for the nonlinear sweep.
- **`Bisection` reports a larger residual than the other line searches, and that is
  correct.** It stops as soon as `f_abstol = 8 eps(T)` is met; the others overshoot
  one to two orders of magnitude below it. Raising `linesearch_max_iterations` from
  the SimpleSolvers default (18/31/60 by precision) to 1000 changes the results not
  at all — bit-identical — so the trial-step budget is not what sets this.
- **Stdlib deps must be declared** in `Project.toml` (`Printf`, `Markdown`,
  `Logging`) with `compat = "1"`: `Pkg.add` otherwise pins them to the running
  Julia's stdlib version, which conflicts with `julia = "1.11"`. After adding package
  deps, re-resolve the **docs** environment
  (`julia --project=docs -e 'using Pkg; Pkg.resolve()'`).
- **`hamiltonian` requires `params` on every method**: `hamiltonian(t, q, params)`
  for the q-only forms (harmonic oscillator, Lotka–Volterra) and
  `hamiltonian(t, q, p, params)` for the double pendulum and Toda lattice (which
  also takes a trailing `N`). There is no parameterless fallback.
- Documenter inlines figures as base64 → raise `size_threshold` in `Documenter.HTML`.
- **Plot/table initial-guess order** is fixed via `_INITIAL_GUESS_ORDER` in
  `plots.jl` (`NoInitialGuess`, `HermiteExtrapolation`, `MidpointExtrapolation`),
  not the benchmark's row order — used by `comparison_figure`, `plot_convergence`,
  and `summary_table`.

## CI (`.github/workflows/CI.yml`)

- `macOS-latest` runners are arm64 — do **not** force `arch: x64` (setup-julia
  errors); leave `arch` unspecified so the runner's native arch is used.
- Pin the Julia matrix to `'1'` (latest stable) rather than a specific unreleased
  version, which fails with "Could not find a Julia version that matches …".
- `nightly` is `continue-on-error` (it often fails upstream and would otherwise
  fail the workflow).
- Pushes to `main` queue (concurrency does not cancel in-progress); Dependabot
  Actions-bump PRs auto-merge and may need a `git rebase origin/main`.

## Key findings

(Re-measured 2026-08-08 against GI 0.17 / GIB 0.5.1 / SimpleSolvers 0.10.1 /
GeometricProblems 0.8.2 / EulerLagrange 0.5.1.)

- `Newton` (robust line search) and `DogLeg` are the most efficient: 1 iter/step on
  the linear oscillator, ~2 on the pendulum and Lotka–Volterra systems.
- **All six line searches are comparably robust**, as is `DogLeg`. Over the twelve
  implicit-midpoint sweeps (108 runs each): Bisection 106, DogLeg 100, Quadratic 99,
  StrongWolfe 99, Static 98, Backtracking 98, BierlaireQuadratic 98, Picard 39.
- **`Bisection` reports the largest residual, and that is correct** — see the gotcha
  above: it stops at `f_abstol`, the others overshoot it.
- `Picard` is slow where it works (oscillator/pendulum: now 9/9 everywhere) and
  **fails entirely** on the Lotka–Volterra `iodeproblem`s and the double pendulum.
  It is the *only* failure at F32/F64 on those problems.
- The oscillator and pendulum are now solved by **every** configuration (72/72 at
  both Δt = 0.1 and Δt = 1.0).
- Precision sets accuracy (energy drift ≈ 1e-17/1e-8/1e-4 for F64/F32/F16); the
  discretization error is precision-independent. `Float16` still largely fails on the
  stiff Lotka–Volterra systems (singular Jacobians).
- Larger time steps increase iteration counts.
- **Nonlinear set**: `Float32` LODE runs are ~100× faster (0.41 s → 0.004 s on the
  harmonic oscillator, now matching `Float64`) — the old Float32 path was
  pathologically slow. Convergence counts are otherwise flat, with three rows lost
  (see the upgrade notes); Δt = 1.0/10.0 still converge nowhere.
