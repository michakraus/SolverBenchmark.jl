# Pendulum

The mathematical pendulum (``\ddot{q} = -\sin q``) is *nonlinear*, so the
implicit midpoint equations require genuine nonlinear iterations at every time
step. This example therefore differentiates the solvers and line searches more
strongly than the [Harmonic Oscillator](@ref).

The benchmark below is regenerated at documentation build time with a single,
fast timing pass. See the driver script `scripts/midpoint_pendulum.jl` for accurate
`BenchmarkTools` measurements. The results are shown first for the standard step
``\Delta t = 0.1`` and then repeated for a coarse step ``\Delta t = 1.0`` (see
[Coarse time step (Δt = 1.0)](@ref pendulum_dt1)).

```@example pendulum
using SolverBenchmark

spec = pendulum_spec(timespan = (0.0, 100.0), timestep = 0.1)
df   = run_benchmark(spec; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

## Convergence

```@example pendulum
plot_convergence(df; title = "Pendulum")
```

## Nonlinear iterations

Mean number of nonlinear-solver iterations per time step (converged runs only):

```@example pendulum
plot_iterations(df)
```

## Run time

```@example pendulum
plot_runtime(df)
```

## Energy drift

Drift of the conserved energy ``H = p^2/(2ml^2) + m g l \cos q``:

```@example pendulum
plot_energy_drift(df)
```

## Discussion

- The problem is **nonlinear**, so Newton needs genuine iterations — about **2
  per step at `Float64`** with `Δt = 0.1`. The robust line searches (`Static`,
  `Backtracking`, `Bisection`, `StrongWolfe`) and `DogLeg` again behave almost
  identically, so in this mildly nonlinear regime the line search barely affects
  the iteration count.
- **`Newton/Quadratic` never converges** on the pendulum — the quadratic line
  search is not robust here.
- **`Picard`** needs roughly 8 iterations per step and is, as for the harmonic
  oscillator, the most sensitive to the initial guess
  (`MidpointExtrapolation` fewest, `NoInitialGuess` most).
- Energy drift scales with precision just as for the [Harmonic Oscillator](@ref).

## Results table

```@example pendulum
markdown_table(summary_table(df))
```

## [Coarse time step (Δt = 1.0)](@id pendulum_dt1)

With a ten times larger step the equations become more strongly nonlinear, which
stresses the solvers noticeably more than the ``\Delta t = 0.1`` results above:
Newton's iteration count rises to ≈ 3.3 per step, `Picard` needs ≈ 30, and
`Newton/BierlaireQuadratic` also stops converging.

```@example pendulum
spec1 = pendulum_spec(timespan = (0.0, 100.0), timestep = 1.0)
df1   = run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

### Convergence

```@example pendulum
plot_convergence(df1; title = "Pendulum (Δt = 1.0)")
```

### Nonlinear iterations

```@example pendulum
plot_iterations(df1)
```

### Run time

```@example pendulum
plot_runtime(df1)
```

### Energy drift

```@example pendulum
plot_energy_drift(df1)
```

### Results table

```@example pendulum
markdown_table(summary_table(df1))
```
