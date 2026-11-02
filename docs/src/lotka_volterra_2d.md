# Lotka–Volterra (2d)

The 2d Lotka–Volterra system is a **non-canonical Hamiltonian system**, benchmarked
here in its implicit form via `iodeproblem` (an implicit ODE / degenerate
Lagrangian). Its Hamiltonian ``H = a_1 q_1 + a_2 q_2 + b_1 \log q_1 + b_2 \log q_2``
depends on the positions ``q`` alone and is used for the energy-drift metric. The
system is stiffer than the oscillator and pendulum, so the native time span
``(0, 10)`` with ``\Delta t = 0.01`` is used; the results are then repeated for a
ten times coarser step ``\Delta t = 0.1`` (see
[Coarse time step (Δt = 0.1)](@ref lotka_volterra_2d_dt01)).

The benchmark below is regenerated at documentation build time with a single, fast
timing pass. See the driver script `scripts/midpoint_lotka_volterra_2d.jl` for accurate
`BenchmarkTools` measurements.

```@example lv2
using SolverBenchmark

spec = lotka_volterra_2d_spec()
df   = cached_sweep("lotka_volterra_2d_dt0.01") do
    run_benchmark(spec; timing = :quick, verbose = false, quiet = true)
end

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
  converge in about 2 iterations per step** at `Float64`, and in about 1 at
  `Float32`.
- **`Picard` never converges** on this system. Its residual
  ``\vartheta(Q) - \bar{p} - \tfrac{h}{2} f`` is not of fixed-point form for the
  non-canonical `iodeproblem` formulation, so the fixed-point iteration has nothing
  to contract. It is the *only* solver that fails at `Float64`; at `Float32`
  `Newton/Quadratic` with `MidpointExtrapolation` fails too.
- **`Float16` largely fails** (7/24 here, 7/24 at the coarse step): the Newton
  linear solve hits singular Jacobians and the trajectory diverges, and here
  `MidpointExtrapolation` also meets the
  [`Float16` midpoint-time collision](@ref float16_midpoint_time). `Float32`
  (20/24) and `Float64` (21/24) behave essentially identically — the achievable
  step accuracy is already reached at `Float32`.
- **`BFloat16` does worse than `Float16`, not better** — 1/24 here and 2/24 at
  the coarse step, against 7/24 and 7/24. This is the comparison the two 16-bit
  formats were added for, and it identifies the cause: the failures come from
  near-singular Jacobians, which need *significand* bits, and `BFloat16` trades
  three of them away for exponent range this problem never needs. (At
  ``\Delta t = 0.01`` the `BFloat16` figure is further depressed by the
  time-grid collision described under [Harmonic Oscillator](@ref); the coarse
  step is the honest comparison.)
- **The 16-bit counts above are those of `scripts/run_all.jl`**, whose
  `BenchmarkTools` timing drives each integrator many times; a later drive can
  raise, and the row is then recorded as not converged. The single timing pass of
  the tables on this page keeps five more `NoInitialGuess` runs: `Float16` 8/24
  and 9/24, `BFloat16` 2/24 and 3/24.
- As always the **initial guess** matters only for the solvers that iterate more;
  for the one- to two-iteration Newton/DogLeg runs it has little effect.

## Results table

```@example lv2
markdown_table(summary_table(df))
```

## [Coarse time step (Δt = 0.1)](@id lotka_volterra_2d_dt01)

The same benchmark over ``(0, 10)`` with a ten times larger step. The problem
becomes harder: the converging solvers need more iterations (≈ 3 per step instead
of ≈ 2), while the same configurations continue to fail (`Picard`, and much of
`Float16`).

```@example lv2
spec1 = lotka_volterra_2d_spec(timespan = (0.0, 10.0), timestep = 0.1)
df1   = cached_sweep("lotka_volterra_2d_dt0.1") do
    run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)
end

nothing # hide
```

### Convergence

```@example lv2
plot_convergence(df1; title = "Lotka–Volterra (2d, Δt = 0.1)")
```

### Nonlinear iterations

```@example lv2
plot_iterations(df1)
```

### Run time

```@example lv2
plot_runtime(df1)
```

### Energy drift

```@example lv2
plot_energy_drift(df1)
```

### Results table

```@example lv2
markdown_table(summary_table(df1))
```
