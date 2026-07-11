# Maintainer notes

Internal notes for developing and extending SolverBenchmark.jl. (User-facing usage
lives in the `README.md` and the [documentation](https://michakraus.github.io/SolverBenchmark.jl/dev/).)

## What this package does

Benchmarks the nonlinear solvers of **SimpleSolvers.jl** (`Newton` with various
line searches, `DogLeg`, `Picard`) as used inside **GeometricIntegrators.jl**'s
`ImplicitMidpoint` on example problems from **GeometricProblems.jl**. It sweeps
precision (`Float16/32/64`) × solver × line search × initial guess and records
convergence, iterations/step, runtime, residual, energy drift, and (where an
analytic solution exists) accuracy.

The harness is problem-/integrator-agnostic so new examples and integrators can be
added easily.

## Code map

- `src/problems.jl` — `ProblemSpec` and the example specs (`harmonic_oscillator_spec`,
  `pendulum_spec`, `lotka_volterra_2d_spec`, `lotka_volterra_4d_spec`). HO/Pendulum
  use `odeproblem`; the Lotka–Volterra systems use `iodeproblem`.
- `src/configurations.jl` — `SolverConfig`/`InitialGuessConfig` and the default grid.
- `src/benchmark.jl` — `run_case`/`run_benchmark` (returns a `DataFrame`).
- `src/plots.jl` — CairoMakie plot helpers, `summary_table`, `markdown_table`.
- `scripts/` — driver scripts (`analysis.jl` shared runner, one per example, and
  `run_all.jl`). Write CSV + figures to `results/` (gitignored); file names embed Δt.
- `docs/` — Documenter site; analysis pages regenerate figures via `@example`
  (`timing=:quick, quiet=true`).

## Non-obvious facts / gotchas

- **Solver stats are not returned by `integrate`.** `run_case` drives the integrator
  step-by-step (`GeometricIntegratorsBase.solutionstep`/`solverstate`, not
  re-exported → `import GeometricIntegratorsBase as GIB`; `GIB.current` must be
  qualified) to read `SimpleSolvers.iteration_number`/`residuals` per step.
- **`DogLeg`/`Picard` reject the `linesearch` keyword** — only `Newton` accepts it.
- **Line-search constructors are precision-typed** (`Backtracking(T)` etc.). For the
  Lotka–Volterra problems there is no `::Type{T}` constructor arg, so precision is
  set by the `q₀` element type — and the parameters must be converted too
  (`_typed_parameters`) or the run mixes precisions.
- **The "Solver took N iterations" warning is gated by `warn_iterations`, not
  `verbosity`.** The harness sets both to 0 and offers `quiet=true` (a `NullLogger`)
  for docs.
- **Stdlib deps must be declared** in `Project.toml` (`Printf`, `Markdown`,
  `Logging`) with `compat = "1"` (Pkg.add pins them to the running Julia's stdlib
  version, which breaks `julia = "1.10"`). After adding package deps, re-resolve the
  **docs** environment (`julia --project=docs -e 'using Pkg; Pkg.resolve()'`).
- **GeometricProblems 0.6.25**: `Pendulum.hamiltonian` now requires `params`
  (`(l, m, g)`) and `odeproblem` carries them. Lotka–Volterra `hamiltonian(t, q, params)`
  depends on `q` alone (params required, no default method).
- Documenter inlines figures as base64 → raise `size_threshold` in `Documenter.HTML`.

## Key findings

- `Newton` (robust line search) and `DogLeg` are the most efficient: 1 iter/step on
  the linear oscillator, ~2 on the pendulum and Lotka–Volterra systems.
- The `Quadratic` line search is fragile; `BierlaireQuadratic` borderline (both fail
  on the pendulum / Lotka–Volterra).
- `Picard` is slow where it works (oscillator/pendulum) and **fails entirely** on the
  non-canonical Lotka–Volterra `iodeproblem`s.
- Precision sets accuracy (energy drift ≈ 1e-17/1e-8/1e-4 for F64/F32/F16); the
  discretization error is precision-independent. `Float16` largely fails on the
  stiff Lotka–Volterra systems (singular Jacobians).
- Larger time steps increase iteration counts and cause more line-search failures.
