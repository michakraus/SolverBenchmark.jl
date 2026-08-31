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
| Precision | `BFloat16`, `Float16`, `Float32`, `Float64` |
| Solver | `Newton`, `DogLeg`, `Picard` |
| Line search (Newton only) | `Static`, `Backtracking`, `Bisection`, `Quadratic`, `BierlaireQuadratic`, `StrongWolfe` |
| Initial guess | `HermiteExtrapolation`, `MidpointExtrapolation`, `NoInitialGuess` (previous step) |

Six example problems are analysed out of the box — the (linear) harmonic
oscillator and the (nonlinear) pendulum, both as `odeproblem`s; the 2d and 4d
Lotka–Volterra systems as `iodeproblem`s (non-canonical Hamiltonian systems);
and the chaotic double pendulum and a 16-site Toda lattice as `hodeproblem`s —
and the design makes it easy to add more problems and integrators.

The two 16-bit formats are both swept because they divide the same 16 bits
differently: `Float16` keeps 11 significand bits and a 5-bit exponent, `BFloat16`
only 8 significand bits but an 8-bit exponent — the same dynamic range as
`Float32`. Running both separates a failure caused by too few digits from one
caused by too little range.

## Usage

Run one of the driver scripts to benchmark a problem with accurate
[`BenchmarkTools`](https://github.com/JuliaCI/BenchmarkTools.jl) timing. Each
writes the raw results to `results/<problem>.csv`, prints a summary table, and
saves the comparison figures to `results/`:

```sh
julia --project=. scripts/midpoint_harmonic_oscillator.jl
julia --project=. scripts/midpoint_pendulum.jl
```

To regenerate every benchmark in the documentation — both the implicit-midpoint
and the nonlinear-integrator experiment sets — run:

```sh
julia --project=. scripts/run_all.jl
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


## Development

### Git hooks

Two hooks live in `.githooks`. They are **not active in a fresh clone** — `core.hooksPath` is local
configuration and does not travel with a push — so enable them once per clone:

```sh
git config core.hooksPath .githooks
```

**`pre-commit`** acts on **staged `.jl` files only**, and exits immediately when a commit stages
none, so a documentation- or workflow-only commit is not slowed down by it:

- **JuliaFormatter `--check`**, honouring this repository's own `.JuliaFormatter.toml` — **blocks**
  the commit. Formatting is mechanical and always fixable.
- **`fatou lint`**, when `fatou` is installed — **advisory only**, and deliberately so: its
  `unused-import` rule does not follow `include`, so it flags the load-bearing imports of every
  module file.
- **`using <Package>`**, which catches a syntax error or a broken `include` — **blocks**.

**`pre-push`** runs the full test suite with `--check-bounds=auto`, but **only when pushing to
`main` or `master`**; a topic branch is left to CI. It prints nothing for **10–30 minutes**, which
looks exactly like a network hang and is not one. If you do interrupt it, check for an orphaned
Julia process that the killed hook left behind.

Either hook can be bypassed for a single command with `--no-verify`, for a change you know it does
not apply to:

```sh
git commit --no-verify
git push --no-verify
```

The hooks are generated from one shared copy and are byte-identical across the related
repositories, so edit them there rather than here — a local edit is silently undone by the next
install.
