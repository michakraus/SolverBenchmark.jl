# Lotka–Volterra (4d)

The 4d Lotka–Volterra system is a larger **non-canonical Hamiltonian system**,
benchmarked in its implicit form via `iodeproblem`. Its Hamiltonian
``H = a \cdot q + b \cdot \log q`` (positions only) is used for the energy-drift
metric. It is more strongly degenerate than the [Lotka–Volterra (2d)](@ref) system
and is the most demanding test for the nonlinear solvers here. As for the 2d case
the native time span ``(0, 10)`` with ``\Delta t = 0.01`` is used, and then
repeated for a ten times coarser step ``\Delta t = 0.1`` (see
[Coarse time step (Δt = 0.1)](@ref lotka_volterra_4d_dt01)).

The benchmark below is regenerated at documentation build time with a single, fast
timing pass. See the driver script `scripts/midpoint_lotka_volterra_4d.jl` for accurate
`BenchmarkTools` measurements.

```@example lv4
using SolverBenchmark

spec = lotka_volterra_4d_spec()
df   = run_benchmark(spec; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

## Convergence

```@example lv4
plot_convergence(df; title = "Lotka–Volterra (4d)")
```

## Nonlinear iterations

Mean number of nonlinear-solver iterations per time step (converged runs only):

```@example lv4
plot_iterations(df)
```

## Run time

```@example lv4
plot_runtime(df)
```

## Energy drift

Drift of the conserved Hamiltonian:

```@example lv4
plot_energy_drift(df)
```

## Discussion

- As for the 2d system, **`Newton` (robust line search) and `DogLeg` converge in
  about 2 iterations per step** at `Float32`/`Float64` (slightly more than the 2d
  case, ≈ 2.3), while **`Picard` never converges** and the `Quadratic` /
  `BierlaireQuadratic` line searches fail throughout.
- The stronger degeneracy makes **`Float16` fail even more readily** — the Newton
  linear solve raises a singular-Jacobian error for most configurations. `Float32`
  and `Float64` again give essentially the same convergence pattern.
- This example demonstrates the harness's robustness: configurations that throw a
  `SingularException` (rather than merely diverging) are caught and recorded as
  non-converged instead of aborting the sweep.

## Results table

```@example lv4
markdown_table(summary_table(df))
```

## [Coarse time step (Δt = 0.1)](@id lotka_volterra_4d_dt01)

The same benchmark over ``(0, 10)`` with a ten times larger step. As for the 2d
system the converging solvers need more iterations (≈ 3.4 per step instead of
≈ 2), the same configurations keep failing, and `Float16` fails almost entirely.

```@example lv4
spec1 = lotka_volterra_4d_spec(timespan = (0.0, 10.0), timestep = 0.1)
df1   = run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

### Convergence

```@example lv4
plot_convergence(df1; title = "Lotka–Volterra (4d, Δt = 0.1)")
```

### Nonlinear iterations

```@example lv4
plot_iterations(df1)
```

### Run time

```@example lv4
plot_runtime(df1)
```

### Energy drift

```@example lv4
plot_energy_drift(df1)
```

### Results table

```@example lv4
markdown_table(summary_table(df1))
```
