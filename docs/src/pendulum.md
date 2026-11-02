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
df   = cached_sweep("pendulum_dt0.1") do
    run_benchmark(spec; timing = :quick, verbose = false, quiet = true)
end

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
  per step at `Float64`** with `Δt = 0.1`. The `Static`, `Backtracking` and
  `StrongWolfe` line searches and `DogLeg` again behave identically, so in this
  mildly nonlinear regime the line search barely affects the iteration count.
  `Bisection` is the exception, at 5.6 iterations per step at `Float64`.
- **Every configuration but `Picard` converges at `Float32` and `Float64`** — 21/24
  at each. `Newton/Quadratic` converges at both, as it does on the
  [Harmonic Oscillator](@ref).
- **`Float16` converges 13/24.** `MidpointExtrapolation` fails for every solver,
  for the reason given under [Harmonic Oscillator](@ref): the `Float16`
  [midpoint time collides](@ref float16_midpoint_time) with the grid.
  `Newton/Quadratic` with `HermiteExtrapolation` fails as well.
- **`BFloat16` converges only with `NoInitialGuess`** (7/24). As for the
  [Harmonic Oscillator](@ref), this is the `BFloat16` time grid rather than the
  solver: at ``\Delta t = 0.1`` over ``(0, 100)`` consecutive times collide, and
  the extrapolating initial guesses cannot difference them. At the
  [coarse step](@ref pendulum_dt1) it recovers to 19/24.
- **`Picard`** converges on none of the 12 runs, at about 2 iterations per step;
  see [Key Findings](@ref) for why.
- Energy drift scales with precision just as for the [Harmonic Oscillator](@ref).

## Results table

```@example pendulum
markdown_table(summary_table(df))
```

## [Coarse time step (Δt = 1.0)](@id pendulum_dt1)

With a ten times larger step the equations become more strongly nonlinear, which
stresses the solvers noticeably more than the ``\Delta t = 0.1`` results above:
Newton's iteration count at `Float32` and `Float64` rises to ≈ 3.4 per step. Every
configuration but `Picard` still converges at those two precisions.

```@example pendulum
spec1 = pendulum_spec(timespan = (0.0, 100.0), timestep = 1.0)
df1   = cached_sweep("pendulum_dt1.0") do
    run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)
end

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
