# Harmonic Oscillator

The harmonic oscillator is a *linear* problem (``\ddot{x} = -k\,x``). Newton's
method therefore solves the implicit midpoint equations exactly in a single
iteration, which makes this example a useful baseline: differences between the
solver configurations are dominated by convergence behaviour and floating point
precision rather than by nonlinearity.

The benchmark below is regenerated at documentation build time with a single,
fast timing pass. See the driver script `scripts/harmonic_oscillator.jl` for
accurate `BenchmarkTools` measurements. The results are shown first for the
standard step ``\Delta t = 0.1`` and then repeated for a coarse step
``\Delta t = 1.0`` (see [Coarse time step (Δt = 1.0)](@ref harmonic_oscillator_dt1)).

```@example ho
using SolverBenchmark

spec = harmonic_oscillator_spec(timespan = (0.0, 100.0), timestep = 0.1)
df   = run_benchmark(spec; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

## Convergence

Which combinations reached the solver tolerance at every time step:

```@example ho
plot_convergence(df; title = "Harmonic Oscillator")
```

## Nonlinear iterations

Mean number of nonlinear-solver iterations per time step (converged runs only):

```@example ho
plot_iterations(df)
```

## Run time

```@example ho
plot_runtime(df)
```

## Energy drift

Drift of the conserved energy ``|H(t_\text{end}) - H(0)|`` — a proxy for the
achievable accuracy at each precision:

```@example ho
plot_energy_drift(df)
```

## Accuracy

Maximum error against the analytic solution:

```@example ho
plot_accuracy(df)
```

## Discussion

- Because the problem is linear, the implicit midpoint equations are linear too,
  so **Newton converges in exactly one iteration per step** for every line search
  that converges (`Static`, `Backtracking`, `Bisection`, `StrongWolfe`), as does
  `DogLeg`. The choice of line search is therefore essentially irrelevant to the
  iteration count here.
- The **`Quadratic` line search is fragile** on this problem (it fails to
  converge at several precisions), and **`BierlaireQuadratic` fails at `Float16`
  and `Float32`**: their bracketing logic is ill-suited to a problem where the
  full Newton step is already exact.
- **`Picard`** (a fixed-point iteration) converges but needs many more iterations
  (≈ 8 per step at `Float64`) and is by far the slowest solver.
- **Precision sets the achievable accuracy**: the energy is conserved to roughly
  machine precision (≈ `1e-17` at `Float64`, `1e-8` at `Float32`, `1e-4` at
  `Float16`), whereas the error against the analytic solution (≈ `5e-4`) is set
  by the ``\mathcal{O}(\Delta t^2)`` midpoint discretization and is essentially
  precision-independent down to `Float32`.
- The **initial guess** does not affect Newton (one exact step regardless), but
  it does affect `Picard`: `MidpointExtrapolation` gives the fewest iterations
  and `NoInitialGuess` (previous step) the most.

## Results table

```@example ho
markdown_table(summary_table(df))
```

## [Coarse time step (Δt = 1.0)](@id harmonic_oscillator_dt1)

The same benchmark with a ten times larger step. For the linear oscillator the
implicit equations stay linear, so `Newton` still converges in one iteration; the
main effect is on `Picard` (many more iterations) and on the energy drift.

```@example ho
spec1 = harmonic_oscillator_spec(timespan = (0.0, 100.0), timestep = 1.0)
df1   = run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

### Convergence

```@example ho
plot_convergence(df1; title = "Harmonic Oscillator (Δt = 1.0)")
```

### Nonlinear iterations

```@example ho
plot_iterations(df1)
```

### Run time

```@example ho
plot_runtime(df1)
```

### Energy drift

```@example ho
plot_energy_drift(df1)
```

### Accuracy

```@example ho
plot_accuracy(df1)
```

### Results table

```@example ho
markdown_table(summary_table(df1))
```
