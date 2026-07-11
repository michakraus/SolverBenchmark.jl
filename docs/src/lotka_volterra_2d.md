# Lotka–Volterra (2d)

The 2d Lotka–Volterra system is a **non-canonical Hamiltonian system**, benchmarked
here in its implicit form via `iodeproblem` (an implicit ODE / degenerate
Lagrangian). Its Hamiltonian ``H = a_1 q_1 + a_2 q_2 + b_1 \log q_1 + b_2 \log q_2``
depends on the positions ``q`` alone and is used for the energy-drift metric. The
system is stiffer than the oscillator and pendulum, so the native time span
``(0, 10)`` with ``\Delta t = 0.01`` is used instead of the coarse
``\Delta t = 0.1``.

The benchmark below is regenerated at documentation build time with a single, fast
timing pass. See the driver script `scripts/lotka_volterra_2d.jl` for accurate
`BenchmarkTools` measurements.

```@example lv2
using SolverBenchmark

spec = lotka_volterra_2d_spec()
df   = run_benchmark(spec; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

## Convergence

```@example lv2
plot_convergence(df; title = "Lotka–Volterra (2d)")
```

## Nonlinear iterations

Mean number of nonlinear-solver iterations per time step (converged runs only):

```@example lv2
plot_iterations(df)
```

## Run time

```@example lv2
plot_runtime(df)
```

## Energy drift

Drift of the conserved Hamiltonian:

```@example lv2
plot_energy_drift(df)
```

## Discussion

- Being an implicit, non-canonical system, the implicit midpoint equations are
  genuinely nonlinear: **`Newton` (with a robust line search) and `DogLeg`
  converge in about 2 iterations per step** at `Float32`/`Float64`.
- **`Picard` never converges** on this system — unlike the harmonic oscillator and
  pendulum (where it converged, if slowly), the fixed-point iteration diverges on
  the non-canonical `iodeproblem` formulation. The `Quadratic` and
  `BierlaireQuadratic` line searches also fail throughout.
- **`Float16` largely fails** (only a handful of runs converge): the Newton
  linear solve hits singular Jacobians and the trajectory diverges. `Float32` and
  `Float64` behave essentially identically here — the achievable step accuracy is
  already reached at `Float32`.
- As always the **initial guess** matters only for the solvers that iterate more;
  for the one- to two-iteration Newton/DogLeg runs it has little effect.

## Results table

```@example lv2
markdown_table(summary_table(df))
```
