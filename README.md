# SolverBenchmark

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://michakraus.github.io/SolverBenchmark.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://michakraus.github.io/SolverBenchmark.jl/dev/)
[![Build Status](https://github.com/michakraus/SolverBenchmark.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/michakraus/SolverBenchmark.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/michakraus/SolverBenchmark.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/michakraus/SolverBenchmark.jl)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/S/SolverBenchmark.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/S/SolverBenchmark.html)

SolverBenchmark compares the nonlinear solver methods provided by
[SimpleSolvers.jl](https://github.com/JuliaGNI/SimpleSolvers.jl) as they are used
inside the implicit integrators of
[GeometricIntegrators.jl](https://github.com/JuliaGNI/GeometricIntegrators.jl),
applied to example problems from
[GeometricProblems.jl](https://github.com/JuliaGNI/GeometricProblems.jl).

Each problem is integrated with the **implicit midpoint** method and the harness
sweeps a grid of options, recording for every run whether the solver converged,
the mean number of nonlinear iterations per step, the run time, the residual, and
— as an accuracy proxy — the drift of the conserved energy (plus the error against
the analytic solution where available).

| Dimension | Values |
|:----------|:-------|
| Precision | `Float16`, `Float32`, `Float64` |
| Solver | `Newton`, `DogLeg`, `Picard` |
| Line search (Newton only) | `Static`, `Backtracking`, `Bisection`, `Quadratic`, `BierlaireQuadratic`, `StrongWolfe` |
| Initial guess | `HermiteExtrapolation`, `MidpointExtrapolation`, `NoInitialGuess` (previous step) |

Four example problems are analysed out of the box — the (linear) harmonic
oscillator and the (nonlinear) pendulum, both as `odeproblem`s, plus the 2d and
4d Lotka–Volterra systems as `iodeproblem`s (non-canonical Hamiltonian systems) —
and the design makes it easy to add more problems and integrators.

## Usage

Run one of the driver scripts to benchmark a problem with accurate
[`BenchmarkTools`](https://github.com/JuliaCI/BenchmarkTools.jl) timing. Each
writes the raw results to `results/<problem>.csv`, prints a summary table, and
saves the comparison figures to `results/`:

```sh
julia --project=. scripts/harmonic_oscillator.jl
julia --project=. scripts/pendulum.jl
```

Or assemble a benchmark programmatically:

```julia
using SolverBenchmark

spec = harmonic_oscillator_spec(timespan = (0.0, 100.0), timestep = 0.1)
df   = run_benchmark(spec)                       # DataFrame of one row per combination

summary_table(df)                                # tidy, sorted view
plot_convergence(df)                             # CairoMakie figures
plot_iterations(df); plot_runtime(df); plot_energy_drift(df); plot_accuracy(df)
```

A new problem is a [`ProblemSpec`](https://michakraus.github.io/SolverBenchmark.jl/dev/api/)
— a `builder` returning an `ODEProblem` at a given precision, an `energy`
function, and an optional analytic `reference`. The set of solvers, line searches,
initial guesses and precisions swept can all be customised via keyword arguments
to `run_benchmark`.

## Documentation

The [documentation](https://michakraus.github.io/SolverBenchmark.jl/dev/) presents
the full results and figures for both example problems and documents the API.
Build it locally with:

```sh
julia --project=docs docs/make.jl
```
