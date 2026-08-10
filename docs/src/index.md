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

Each problem is integrated with the **implicit midpoint** method, over the time
span and step size that suit it (``(0, 100)`` at ``\Delta t = 0.1`` for the
oscillator, pendulum and Toda lattice; ``(0, 10)`` at ``\Delta t = 0.01`` for the
stiffer Lotka–Volterra and double-pendulum systems), and each is also run at a ten
times coarser step. The following options are swept:

| Dimension | Values |
|:----------|:-------|
| Precision | `BFloat16`, `Float16`, `Float32`, `Float64` |
| Solver | `Newton`, `DogLeg`, `Picard` |
| Line search (Newton only) | `Static`, `Backtracking`, `Bisection`, `Quadratic`, `BierlaireQuadratic`, `StrongWolfe` |
| Initial guess | `HermiteExtrapolation`, `MidpointExtrapolation`, `NoInitialGuess` (previous step) |

This yields eight solver configurations (six Newton line searches plus `DogLeg`
and `Picard`) times four precisions times three initial guesses — 96 runs per
problem.

Both 16-bit formats are swept because they divide the same 16 bits differently:
`Float16` keeps 11 significand bits and a 5-bit exponent, `BFloat16` only 8
significand bits but an 8-bit exponent — the same dynamic range as `Float32`.
Running both separates a failure caused by too few digits from one caused by
overflow or underflow.

For every run the harness records whether the solver converged, the mean number
of nonlinear iterations per time step, the run time, the residual, and — as an
accuracy proxy — the drift of the conserved energy (and, where available, the
error against the analytic solution).

A second experiment set uses the neural-network variational integrator
`NonLinear_OneLayer_GML` from
[NonlinearIntegrators.jl](https://github.com/JuliaGNI/NonlinearIntegrators.jl)
instead of implicit midpoint. Because that integrator's nonlinear system is
near-singular, the sweep varies the solver's **regularization factor** ``\lambda``
(in place of the initial guess): the ``\lambda = 0`` control plus six rungs of a
ladder of multiples of ``\sqrt{\varepsilon(T)}``, so that the shift is scaled to the
precision it protects rather than fixed in absolute terms (see
[How the regularization factor scales](@ref)). That runs across the four precisions
and a reduced set of four solver configurations (`Newton/Static`,
`Newton/Backtracking`, `Newton/StrongWolfe`, `DogLeg`), at the step sizes
``\Delta t = 0.1, 1.0, 10.0`` (ten steps each) — 112 runs per sweep.

## Analyses

### Implicit Midpoint

- [Harmonic Oscillator](@ref) — a linear problem; the solvers converge in a
  single Newton iteration.
- [Pendulum](@ref) — a nonlinear problem that exercises the solvers more.
- [Lotka–Volterra (2d)](@ref) and [Lotka–Volterra (4d)](@ref) — non-canonical
  Hamiltonian systems built as `iodeproblem`s (implicit ODE / degenerate
  Lagrangian form); stiffer problems where low precision starts to fail.
- [Double Pendulum](@ref) — a chaotic `hodeproblem` (canonical Hamiltonian form)
  whose Hamiltonian depends on both `q` and `p`.
- [Toda Lattice](@ref) — a 16-site `hodeproblem`, the highest-dimensional problem
  of the implicit-midpoint set.

### Nonlinear Integrator

- [Harmonic Oscillator (Nonlinear Integrator)](@ref) — the one-layer network
  variational integrator, where a nonzero regularization factor is essential for
  the Newton solve to converge.
- [Pendulum (Nonlinear Integrator)](@ref) — a nonlinear problem (built from the
  pendulum's phase-space `iodeproblem`).
- [Double Pendulum (Nonlinear Integrator)](@ref) — a chaotic, strongly nonlinear
  system; `DogLeg` is the most robust solver here.
- [Toda Lattice (Nonlinear Integrator)](@ref) — a 16-dimensional lattice, the
  highest-dimensional problem in the study.

The Lotka–Volterra systems are omitted from the nonlinear-integrator study: their
degenerate Lagrangians are not currently supported by `NonLinear_OneLayer_GML`.

## Key findings

The [Key Findings](@ref) page collects what the two experiment sets measured. In
brief:

- **`Newton` with a robust line search, and `DogLeg`, are the most efficient**, at
  about 1.15 iterations per step on the oscillator and pendulum. All six line
  searches are comparably robust; the choice between them matters far less than the
  choice of solver, and `Picard` is the outlier that fails outright on four of the
  six problems.
- **Precision sets the achievable accuracy**, and `Float32` already reaches the
  ``\mathcal{O}(\Delta t^2)`` discretization error.
- **The two 16-bit formats show that the low-precision failures are about
  significand bits, not exponent range**: `BFloat16` never beats `Float16` where the
  comparison is clean, despite its `Float32`-sized exponent. It has a separate
  limitation of its own — it cannot resolve a fine time grid.
- **`Bisection` stops at the tolerance it was asked for** while the others overshoot
  it, so residuals must be read against `f_abstol` rather than against each other.

## Reproducing the results

The pages above regenerate their figures at documentation build time using a
single, fast timing pass (`timing = :quick`). For accurate run-time
measurements, run the driver scripts, which use `BenchmarkTools` and also write
the raw results to `results/`:

```julia
julia --project=. scripts/midpoint_harmonic_oscillator.jl
julia --project=. scripts/midpoint_pendulum.jl
```

`scripts/run_all.jl` runs every benchmark on this site — both experiment sets, at
both step sizes — in one go.

See the [API](@ref) for the building blocks used to define new problems and
assemble custom benchmarks.
