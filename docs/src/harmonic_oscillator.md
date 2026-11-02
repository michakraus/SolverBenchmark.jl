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
df   = cached_sweep("harmonic_oscillator_dt0.1") do
    run_benchmark(spec; timing = :quick, verbose = false, quiet = true)
end

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
  so **Newton converges in exactly one iteration per step** with the `Static`,
  `Backtracking`, `BierlaireQuadratic` and `StrongWolfe` line searches, as does
  `DogLeg` except at `Float16` (1.07). `Bisection` is the exception, at up to 5
  iterations per step at `Float64`, and `Quadratic` takes 1.3 at `Float32`.
- **Every configuration but `Picard` converges at `Float32` and `Float64`**: 21/24
  at each. That includes the `Quadratic` and `BierlaireQuadratic` line searches,
  which need SimpleSolvers 0.10 or later to converge here.
- **`Float16` converges 14/24**: besides `Picard`, `MidpointExtrapolation` fails
  for every solver. From ``t = 64.2`` on, the midpoint time ``t - \Delta t/2``
  rounds onto the previous grid time at `Float16`, and that initial guess turns
  `NaN` (see [the midpoint-time collision](@ref float16_midpoint_time)).
- **`BFloat16` converges only with `NoInitialGuess`** (7/24), and the reason has
  nothing to do with the solver. With 8 significand bits the spacing of
  `BFloat16` at ``t = 100`` is `0.5`, five times the step, so the time series
  `0:0.1:100` holds 1001 points but only 451 distinct values; the two
  extrapolating initial guesses are then handed two identical times and abort.
  At the [coarse step](@ref harmonic_oscillator_dt1) the grid resolves and 22 of
  the 24 `BFloat16` runs converge — the one place in this study where a *larger*
  time step helps.
- **`Bisection` stops at the requested tolerance**; the others overshoot it. Its
  residual sits right at `f_abstol = 8 eps(T)`, whereas the remaining line
  searches drive it a further two to three orders of magnitude down. All of them
  converge — the difference is how far past the tolerance they go, not whether
  they reach it. The results table flags this in the `at_tolerance` column.
- **`Picard`** (a fixed-point iteration) converges on none of the 12 runs. It
  stops after about 2 iterations per step with a residual of `2.2e-4` to `0.25`
  at `Float32` and `Float64`, far above the tolerance; see
  [Key Findings](@ref) for why.
- **Precision sets the achievable accuracy**: the energy is conserved to roughly
  machine precision (≈ `7e-17` at `Float64`, `1e-7` at `Float32`, `4e-4` at
  `Float16` and `4e-3` at `BFloat16`), whereas the error against the analytic
  solution is set by the ``\mathcal{O}(\Delta t^2)`` midpoint discretization. That
  discretization error (`1.47e-2`) is reached exactly by `Float32` and `Float64`;
  `Float16` (`9.6e-3` … `2.4e-2`) and `BFloat16` (`2.1e-2` … `7.5e-2`) scatter
  about it and above it, round-off rather than discretization limited — and the
  gap between the two 16-bit formats is the three significand bits between them.
- The **initial guess** does not affect Newton (one exact step regardless); it
  matters only at reduced precision, through the time grid above.

## Results table

```@example ho
markdown_table(summary_table(df))
```

## [Coarse time step (Δt = 1.0)](@id harmonic_oscillator_dt1)

The same benchmark with a ten times larger step. For the linear oscillator the
implicit equations stay linear, so `Newton` still converges in one iteration; the
main effect is on the energy drift. `Picard` converges on one run, `BFloat16` with
`MidpointExtrapolation`, inside a tolerance of `0.0625`.

```@example ho
spec1 = harmonic_oscillator_spec(timespan = (0.0, 100.0), timestep = 1.0)
df1   = cached_sweep("harmonic_oscillator_dt1.0") do
    run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)
end

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
