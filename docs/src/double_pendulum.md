# Double Pendulum

The double pendulum is a *chaotic*, strongly nonlinear Hamiltonian system. It is
built here with `hodeproblem` (the canonical Hamiltonian form), so the implicit
midpoint equations require genuine nonlinear iterations at every step. Because
the Hamiltonian ``H(t, q, p)`` depends on both the coordinates ``q`` and the
momenta ``p``, the energy-drift proxy is evaluated from the full ``(q, p)`` state.

The benchmark below is regenerated at documentation build time with a single,
fast timing pass. See the driver script `scripts/double_pendulum.jl` for accurate
`BenchmarkTools` measurements. The results are shown first for the standard step
``\Delta t = 0.01`` and then repeated for a coarse step ``\Delta t = 0.1`` (see
[Coarse time step (Δt = 0.1)](@ref double_pendulum_dt01)).

```@example dp
using SolverBenchmark

spec = double_pendulum_spec(timespan = (0.0, 10.0), timestep = 0.01)
df   = run_benchmark(spec; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

## Convergence

```@example dp
plot_convergence(df; title = "Double Pendulum")
```

## Nonlinear iterations

Mean number of nonlinear-solver iterations per time step (converged runs only):

```@example dp
plot_iterations(df)
```

## Run time

```@example dp
plot_runtime(df)
```

## Energy drift

Drift of the conserved energy ``H(t, q, p)`` of the double pendulum:

```@example dp
plot_energy_drift(df)
```

## Discussion

- The problem is **chaotic and nonlinear**, so Newton needs genuine iterations at
  every step. The robust line searches behave similarly, while the less robust
  ones (e.g. `Newton/Quadratic`) may fail to converge.
- No closed-form solution is available, so accuracy is judged solely through the
  energy drift, which scales with the floating point precision.

## Results table

```@example dp
markdown_table(summary_table(df))
```

## [Coarse time step (Δt = 0.1)](@id double_pendulum_dt01)

With a ten times larger step the equations become more strongly nonlinear, which
stresses the solvers noticeably more than the ``\Delta t = 0.01`` results above.

```@example dp
spec1 = double_pendulum_spec(timespan = (0.0, 10.0), timestep = 0.1)
df1   = run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

### Convergence

```@example dp
plot_convergence(df1; title = "Double Pendulum (Δt = 0.1)")
```

### Nonlinear iterations

```@example dp
plot_iterations(df1)
```

### Run time

```@example dp
plot_runtime(df1)
```

### Energy drift

```@example dp
plot_energy_drift(df1)
```

### Results table

```@example dp
markdown_table(summary_table(df1))
```
