# Double Pendulum (Nonlinear Integrator)

The double pendulum benchmarked with the `NonLinear_OneLayer_GML` integrator (see
[Harmonic Oscillator (Nonlinear Integrator)](@ref) for the network setup and the
regularization sweep). It is built as a two-dimensional `lodeproblem`; being
chaotic and strongly nonlinear, it is a demanding test for the implicit network
solve. Its Hamiltonian depends on both `q` and `p`, so the energy drift is
evaluated from the full state. No closed-form solution exists.

The figures panel by the regularization factor ``\lambda``; solver configurations
are on the x-axis and precisions are distinguished by colour. Results are shown at
``\Delta t = 0.1`` and repeated for ``\Delta t = 1.0`` and ``\Delta t = 10.0``
(ten steps each).

```@example nldp
using SolverBenchmark

spec = double_pendulum_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)
df   = run_nonlinear_benchmark(spec; timing = :quick, max_iterations = 100,
                               verbose = false, quiet = true)

nothing # hide
```

## Convergence

```@example nldp
plot_convergence(df; panelcol = :regularization, title = "Double Pendulum (nonlinear)")
```

## Nonlinear iterations

```@example nldp
plot_iterations(df; panelcol = :regularization)
```

## Run time

```@example nldp
plot_runtime(df; panelcol = :regularization)
```

## Energy drift

```@example nldp
plot_energy_drift(df; panelcol = :regularization)
```

## Discussion

- **Regularization is again decisive**: `Newton` stalls at ``\lambda = 0`` and
  converges in a few iterations once ``\lambda > 0``. `DogLeg` (a trust-region
  method) is the most robust here — it can make progress even at ``\lambda = 0``,
  where the line-search Newton variants do not.
- The chaotic dynamics give a larger energy drift than the integrable examples,
  and the achievable step size is smaller — at ``\Delta t = 1.0`` and above the
  solve struggles.
- `Float16` fails (singular Newton Jacobian).

## Results table

```@example nldp
markdown_table(summary_table(df; panelcol = :regularization))
```

## Coarse time step (Δt = 1.0)

```@example nldp
spec1 = double_pendulum_lode_spec(timespan = (0.0, 10.0), timestep = 1.0)
df1   = run_nonlinear_benchmark(spec1; timing = :quick, max_iterations = 100,
                                verbose = false, quiet = true)
nothing # hide
```

```@example nldp
plot_convergence(df1; panelcol = :regularization, title = "Double Pendulum (nonlinear, Δt = 1.0)")
```

```@example nldp
markdown_table(summary_table(df1; panelcol = :regularization))
```

## Large time step (Δt = 10.0)

```@example nldp
spec10 = double_pendulum_lode_spec(timespan = (0.0, 100.0), timestep = 10.0)
df10   = run_nonlinear_benchmark(spec10; timing = :quick, max_iterations = 100,
                                 verbose = false, quiet = true)
nothing # hide
```

```@example nldp
plot_convergence(df10; panelcol = :regularization, title = "Double Pendulum (nonlinear, Δt = 10.0)")
```

```@example nldp
markdown_table(summary_table(df10; panelcol = :regularization))
```
