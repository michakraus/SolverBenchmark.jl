```@meta
CurrentModule = SolverBenchmark
```

# Internals

How the harness is put together, and the things about the Geometric* stack that are
not obvious from its interfaces. This page is for extending the package — adding a
problem, an integrator or a metric. See [Low-Precision Support](@ref) for everything
specific to the 16-bit formats and [Maintenance](@ref) for the build and CI.

## What the package does

It benchmarks the nonlinear solvers of
[SimpleSolvers.jl](https://github.com/JuliaGNI/SimpleSolvers.jl) — `Newton` with six
line searches, `DogLeg` and `Picard` — *as they are used inside implicit
integrators*, on example problems from
[GeometricProblems.jl](https://github.com/JuliaGNI/GeometricProblems.jl). Every run
records convergence, iterations per step, run time, residual, energy drift and,
where an analytic solution exists, accuracy. There are two experiment sets — implicit
midpoint, and `NonLinear_OneLayer_GML` from
[NonlinearIntegrators.jl](https://github.com/JuliaGNI/NonlinearIntegrators.jl); the
[Home](@ref SolverBenchmark) page gives the grid each one sweeps.

Nothing in the harness knows which problem or integrator it is running, so both sets
share the same machinery and new examples are cheap to add. That is the design
constraint worth preserving when extending it.

## Code map

| File | Contents |
|:-----|:---------|
| `src/problems.jl` | [`ProblemSpec`](@ref) and the implicit-midpoint specs. Oscillator and pendulum use `odeproblem`, Lotka–Volterra 2d/4d `iodeproblem`, double pendulum and Toda lattice (``N = 16``) `hodeproblem`. |
| `src/configurations.jl` | [`SolverConfig`](@ref)/[`InitialGuessConfig`](@ref), [`solver_label`](@ref)/[`precision_label`](@ref), and the default grid. |
| `src/benchmark.jl` | Solver options, the `quiet` logger, [`run_case`](@ref)/[`run_benchmark`](@ref). |
| `src/nonlinear.jl` | The second experiment set: LODE specs, activation factories ([`relu_k`](@ref)/[`gelu`](@ref)/[`elu`](@ref)), [`nonlinear_onelayer_method`](@ref), [`run_nonlinear_case`](@ref)/[`run_nonlinear_benchmark`](@ref). |
| `src/bfloat16.jl` | The `BFloat16` compatibility layer — see [Low-Precision Support](@ref). |
| `src/plots.jl` | CairoMakie helpers, [`summary_table`](@ref), [`markdown_table`](@ref). |
| `scripts/` | `midpoint_analysis.jl`/`nonlinear_analysis.jl` shared runners, one script per example, `run_all.jl` (everything in these docs), and the standalone `nonlinear_activation_study.jl`/`f_abstol_study.jl`. All write CSV and figures to `results/` (gitignored) with ``\Delta t`` embedded in the file names. |

A problem is described entirely by a [`ProblemSpec`](@ref): a name, a
`builder(T)` returning the problem at precision `T`, an `energy` closure, an
optional analytic `reference`, and the residual-tolerance factor. That is the whole
extension point.

## Driving the integrator by hand

**Solver statistics are not returned by `integrate`.** To read them,
[`run_case`](@ref) steps the integrator itself, using the low-level API from
`GeometricIntegratorsBase` — `solutionstep`, `solverstate`, `current` — and reads
`SimpleSolvers.iteration_number` and `residuals` after every time step.

Those functions are not re-exported by `GeometricIntegrators`, so the package
imports the base module under an alias (`import GeometricIntegratorsBase as GIB`)
and `GIB.current` in particular must stay qualified.

This is also why every metric is per-run rather than per-step: the harness
aggregates as it steps, keeping one row per configuration.

## Errors are recorded, not raised

[`run_case`](@ref) and [`run_nonlinear_case`](@ref) catch **every** exception and
record a non-converged row, so that one diverging configuration cannot abort a
96-run sweep. `run_nonlinear_benchmark` extends the same treatment to the
once-per-precision network build.

The cost of that robustness is worth stating plainly:

!!! warning "A missing method looks exactly like non-convergence"
    Because any exception becomes a non-converged row, an unimplemented method, a
    thrown `ArgumentError` and a genuinely diverging solve are indistinguishable in
    the results. Before writing up any new failure, re-run that single case with
    `quiet = false` and read the exception. Every gap in the
    [`BFloat16` layer](@ref "Low-Precision Support") first presented as
    "`BFloat16` does not converge on this problem".

## Solver options

Options are merged over `default_options(method, problem)`, so `_solver_options`
lists only what it changes.

- **The framework `f_abstol` default is `max(8, solversize(method, problem)) * eps(T)`,
  but measured it is `8 eps(T)` for every problem here** — including the Toda lattice
  at ``N = 16``, whose 32 unknowns would otherwise raise it. `GeometricIntegrators`
  declares its `solversize` methods as `solversize(problem, method)` while
  `GeometricIntegratorsBase`'s `default_options` calls `solversize(method, problem)`,
  so the `hodeproblem`s fall through to the generic
  `solversize(::GeometricMethod, ::GeometricProblem) = 0`. Do not assume the
  size-proportional default is active; `f_abstol_factor` is measured against
  `8 eps(T)`.
- **The "Solver took N iterations" warning is gated by `warn_iterations`, not
  `verbosity`.** The harness sets both to `0`.
- **`DogLeg` and `Picard` reject the `linesearch` keyword** — only `Newton` accepts
  it. Hence the `linesearch === nothing` branch in [`SolverConfig`](@ref).

## Constructing problems at a given precision

- **Line-search constructors are precision-typed** (`Backtracking(T)`,
  `Bisection(T)`, …), which is why [`SolverConfig`](@ref) stores a callable
  `T -> LinesearchMethod` rather than an instance.
- **Problem constructors take no `::Type{T}` argument.** Precision comes from the
  element type of `q₀`/`p₀`, so a spec must *also* pass
  `parameters = Module.default_parameters(T)` — otherwise the parameters stay
  `Float64` and the run silently mixes precisions.
- **`hamiltonian` requires `params` on every method**: `hamiltonian(t, q, params)`
  for the q-only forms (harmonic oscillator, Lotka–Volterra) and
  `hamiltonian(t, q, p, params)` for the double pendulum and Toda lattice (which
  also takes a trailing `N`). There is no parameterless fallback.

## `quiet = true` filters, it does not muffle

`quiet = true` installs a filtering logger, not a `NullLogger`. `verbosity = 0`
already silences the benchmarked solver, so the filter only has to drop the two
sources that no solver option reaches:

1. `GeometricIntegratorsBase`'s `HermiteExtrapolation` "history identical" warning —
   its `nowarn` keyword is not threaded through `GeometricIntegrator`.
2. The inner `integrate(tem_ode, ImplicitMidpoint())` that `NonLinear_OneLayer_GML`
   runs once per step to seed its `IntegratorExtrapolation`. It is called with no
   options, so it uses SimpleSolvers' defaults (`verbosity = 1`,
   `warn_iterations = 1000`, `Backtracking`) no matter how the outer solver is
   configured.

Forwarding options to that inner call upstream would let `quiet` be retired for the
nonlinear sweep.

## Plot and table conventions

- **Display order is fixed by constants in `src/plots.jl`, not by row order.**
  `_PRECISION_ORDER` (`BFloat16`, `Float16`, `Float32`, `Float64`) and
  `_INITIAL_GUESS_ORDER` (`NoInitialGuess`, `HermiteExtrapolation`,
  `MidpointExtrapolation`) drive [`comparison_figure`](@ref),
  [`plot_convergence`](@ref) and [`summary_table`](@ref).
- **The precision axis is filtered against `_PRECISION_ORDER` by string equality,
  and unrecognised values are silently dropped** — no error, just missing bars. This
  is why the `precision` column is written with [`precision_label`](@ref) (i.e.
  `nameof(T)`) rather than `string(T)`: Julia renders a type module-qualified
  whenever its module is not visible from `Main`, so `string(BFloat16)` is
  `"BFloat16s.BFloat16"` inside a Documenter `@example` sandbox.
- The regularization panels of the nonlinear sweep have no order constant; they rely
  on `_ordered` appending unlisted values in first-appearance order, which works
  because ``\lambda`` is the innermost loop.
