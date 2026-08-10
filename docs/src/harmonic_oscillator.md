# Harmonic Oscillator

The harmonic oscillator is a *linear* problem (``\ddot{x} = -k\,x``). Newton's
method therefore solves the implicit midpoint equations exactly in a single
iteration, which makes this example a useful baseline: differences between the
solver configurations are dominated by convergence behaviour and floating point
precision rather than by nonlinearity.

The benchmark below is regenerated at documentation build time with a single,
fast timing pass. See the driver script `scripts/midpoint_harmonic_oscillator.jl` for
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
  so **Newton converges in exactly one iteration per step** for every line search,
  as does `DogLeg`. The choice of line search is therefore essentially irrelevant
  to the iteration count here.
- **Every configuration converges at `Float16` and above**: 72 of the 96 runs —
  eight solver configurations × three initial guesses at each of `Float16`,
  `Float32` and `Float64`. That includes the `Quadratic` and `BierlaireQuadratic`
  line searches, which need SimpleSolvers 0.10 or later to converge here.
- **`BFloat16` converges only with `NoInitialGuess`** (8/24), and the reason has
  nothing to do with the solver. With 8 significand bits the spacing of
  `BFloat16` at ``t = 100`` is `0.5`, five times the step, so the time series
  `0:0.1:100` holds 1001 points but only 451 distinct values; the two
  extrapolating initial guesses are then handed two identical times and abort.
  At the [coarse step](@ref harmonic_oscillator_dt1) the grid resolves and all
  24 `BFloat16` runs converge — the one place in this study where a *larger*
  time step helps.
- **`Bisection` stops at the requested tolerance**; the others overshoot it. Its
  residual sits right at `f_abstol = 8 eps(T)`, whereas the remaining line
  searches drive it a further two to three orders of magnitude down. All of them
  converge — the difference is how far past the tolerance they go, not whether
  they reach it. The results table flags this in the `at_tolerance` column.
- **`Picard`** (a fixed-point iteration) converges but needs many more iterations
  and is by far the slowest solver. Its iteration count is set by how far the
  tolerance is from the guess, so it *rises* with precision here: ≈ 1 per step at
  `Float16`, 2–3 at `Float32`, 7–9 at `Float64`.
- **Precision sets the achievable accuracy**: the energy is conserved to roughly
  machine precision (≈ `7e-17` at `Float64`, `1e-7` at `Float32`, `4e-4` at both
  16-bit formats), whereas the error against the analytic solution is set by the
  ``\mathcal{O}(\Delta t^2)`` midpoint discretization. That discretization error
  (`1.47e-2`) is reached exactly by `Float32` and `Float64`; `Float16`
  (`2.0e-2` … `2.6e-2`) and `BFloat16` (`3.0e-2` … `7.5e-2`) sit above it,
  round-off rather than discretization limited — and the gap between the two
  16-bit formats is the three significand bits between them.
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
