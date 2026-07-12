```@meta
CurrentModule = SolverBenchmark
```

# SolverBenchmark

[SolverBenchmark](https://github.com/michakraus/SolverBenchmark.jl) benchmarks the
nonlinear solver methods provided by
[SimpleSolvers.jl](https://github.com/JuliaGNI/SimpleSolvers.jl) as they are used
inside the implicit integrators of
[GeometricIntegrators.jl](https://github.com/JuliaGNI/GeometricIntegrators.jl),
applied to example problems from
[GeometricProblems.jl](https://github.com/JuliaGNI/GeometricProblems.jl).

Each problem is integrated with the **implicit midpoint** method over the time
interval ``(0, 100)`` with a step size of ``0.1``, and the following options are
swept:

| Dimension | Values |
|:----------|:-------|
| Precision | `Float16`, `Float32`, `Float64` |
| Solver | `Newton`, `DogLeg`, `Picard` |
| Line search (Newton only) | `Static`, `Backtracking`, `Bisection`, `Quadratic`, `BierlaireQuadratic`, `StrongWolfe` |
| Initial guess | `HermiteExtrapolation`, `MidpointExtrapolation`, `NoInitialGuess` (previous step) |

This yields eight solver configurations (six Newton line searches plus `DogLeg`
and `Picard`) times three precisions times three initial guesses — 72 runs per
problem.

For every run the harness records whether the solver converged, the mean number
of nonlinear iterations per time step, the run time, the residual, and — as an
accuracy proxy — the drift of the conserved energy (and, where available, the
error against the analytic solution).

A second experiment set uses the neural-network variational integrator
`NonLinear_OneLayer_GML` from
[NonlinearIntegrators.jl](https://github.com/JuliaGNI/NonlinearIntegrators.jl)
instead of implicit midpoint. Because that integrator's nonlinear system is
near-singular, the sweep varies the solver's **regularization factor**
``\lambda \in \{0, 10^{-3}, 10^{-5}, 10^{-7}\}`` (in place of the initial guess)
across the three precisions and a reduced set of four solver configurations
(`Newton/Static`, `Newton/Backtracking`, `Newton/StrongWolfe`, `DogLeg`), at the
step sizes ``\Delta t = 0.1, 1.0, 10.0`` (ten steps each).

## Analyses

### Implicit Midpoint

- [Harmonic Oscillator](@ref) — a linear problem; the solvers converge in a
  single Newton iteration.
- [Pendulum](@ref) — a nonlinear problem that exercises the solvers more.
- [Lotka–Volterra (2d)](@ref) and [Lotka–Volterra (4d)](@ref) — non-canonical
  Hamiltonian systems built as `iodeproblem`s (implicit ODE / degenerate
  Lagrangian form); stiffer problems where low precision starts to fail.

### Nonlinear Integrator

- [Harmonic Oscillator (Nonlinear Integrator)](@ref) — the one-layer network
  variational integrator, where a nonzero regularization factor is essential for
  the Newton solve to converge.

## Key findings

- **`Newton` with a robust line search, and `DogLeg`, are the most efficient**:
  one iteration per step on the (linear) oscillator, about two on the pendulum.
- **The `Quadratic` line search is fragile** — it fails on the oscillator at low
  precision and never converges on the pendulum; `BierlaireQuadratic` is
  borderline and starts failing at lower precision and larger time steps.
- **`Picard` is slow where it works and fragile where it does not**: on the
  oscillator and pendulum it converges but needs many iterations (≈ 8 to 30 per
  step) and is the most guess-sensitive; on the non-canonical Lotka–Volterra
  `iodeproblem`s it **fails to converge entirely**.
- **`MidpointExtrapolation` tends to give the best initial guess** (fewest Picard
  iterations); `NoInitialGuess` (reuse of the previous step) the worst.
- **Precision sets the achievable accuracy** (energy drift ≈ `1e-17`, `1e-8`,
  `1e-4` for `Float64`, `Float32`, `Float16`), while the discretization error is
  precision-independent.
- **Larger time steps** increase iteration counts and cause more line-search
  failures.

## Reproducing the results

The pages above regenerate their figures at documentation build time using a
single, fast timing pass (`timing = :quick`). For accurate run-time
measurements, run the driver scripts, which use `BenchmarkTools` and also write
the raw results to `results/`:

```julia
julia --project=. scripts/harmonic_oscillator.jl
julia --project=. scripts/pendulum.jl
```

See the [API](@ref) for the building blocks used to define new problems and
assemble custom benchmarks.
