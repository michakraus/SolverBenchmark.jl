# Double Pendulum

The double pendulum is a *chaotic*, strongly nonlinear Hamiltonian system. It is
built here with `hodeproblem` (the canonical Hamiltonian form), so the implicit
midpoint equations require genuine nonlinear iterations at every step. Because
the Hamiltonian ``H(t, q, p)`` depends on both the coordinates ``q`` and the
momenta ``p``, the energy-drift proxy is evaluated from the full ``(q, p)`` state.

Because the forces are ``O(g m l)``, this problem's nonlinear residual bottoms out
well above ``\varepsilon(T)``, so the solver tolerance is relaxed to
``256\,\varepsilon(T)``. That floor is a property of the problem's scale, not of
the precision: measured, it sits at ``\approx 200 \dots 260\,\varepsilon(T)`` at
**every** precision. It is also why the results table below carries an
`at_tolerance` column with every row flagged — on this problem a converged run
stops *at* its target rather than below it. Read the caveat literally at 16-bit:
``256\,\varepsilon(\texttt{BFloat16})`` is ``2.0``, comparable to the energy
itself, so a `BFloat16` row here reports having met a target too loose to say much.

The benchmark below is regenerated at documentation build time with a single,
fast timing pass. See the driver script `scripts/midpoint_double_pendulum.jl` for accurate
`BenchmarkTools` measurements. The results are shown first for the standard step
``\Delta t = 0.01`` and then repeated for a coarse step ``\Delta t = 0.1`` (see
[Coarse time step (Δt = 0.1)](@ref double_pendulum_dt01)).

```@example dp
using SolverBenchmark

spec = double_pendulum_spec(timespan = (0.0, 10.0), timestep = 0.01)
df   = cached_sweep("double_pendulum_dt0.01") do
    run_benchmark(spec; timing = :quick, verbose = false, quiet = true)
end

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
  every step. All six line searches behave similarly; `Newton/Quadratic` is the
  weakest of them but still converges for two thirds of the runs. `Picard` never
  converges here, and at `Δt = 0.01` it is the only failure at
  `Float32`/`Float64`; at the coarse step `DogLeg` joins it.
- **Precision dominates**: 21/24 at both `Float32` and `Float64`, 11/24 at
  `Float16` and 5/24 at `BFloat16` (58/96 overall; 64/96 at the coarse step).
  Every converged row is flagged in the `at_tolerance` column, because on this
  problem the residual floor *is* the tolerance — see the note above.
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
df1   = cached_sweep("double_pendulum_dt0.1") do
    run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)
end

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
