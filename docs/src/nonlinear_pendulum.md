# Pendulum (Nonlinear Integrator)

The mathematical pendulum benchmarked with the `NonLinear_OneLayer_GML` integrator
(see [Harmonic Oscillator (Nonlinear Integrator)](@ref) for the network setup and
the meaning of the regularization sweep). `GeometricProblems.Pendulum` provides no
Lagrangian (`lodeproblem`) form, so its two-dimensional phase-space `iodeproblem`
is used — the state is `q = [angle, momentum]`, and the energy
``H(\text{angle}, \text{momentum})`` is evaluated from both components. The
pendulum is nonlinear, so it exercises the solves more than the harmonic
oscillator. No closed-form solution is used; accuracy is assessed through the
energy drift.

The figures panel by the regularization factor ``\lambda``; solver configurations
are on the x-axis and precisions are distinguished by colour. Results are shown at
``\Delta t = 0.1`` and repeated for ``\Delta t = 1.0`` and ``\Delta t = 10.0``
(ten steps each).

```@example nlpen
using SolverBenchmark

spec = pendulum_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)
df   = run_nonlinear_benchmark(spec; timing = :quick, max_iterations = 100,
                               verbose = false, quiet = true)

nothing # hide
```

## Convergence

```@example nlpen
plot_convergence(df; panelcol = :regularization, title = "Pendulum (nonlinear)")
```

## Nonlinear iterations

```@example nlpen
plot_iterations(df; panelcol = :regularization)
```

## Run time

```@example nlpen
plot_runtime(df; panelcol = :regularization)
```

## Energy drift

```@example nlpen
plot_energy_drift(df; panelcol = :regularization)
```

## Discussion

- As for the harmonic oscillator, **a nonzero regularization factor is required**:
  with ``\lambda = 0`` the Newton iteration stalls, while ``\lambda > 0`` converges
  in a handful of iterations, conserving the energy to ``\approx 10^{-8}`` at
  `Float64`.
- The pendulum's nonlinearity means the solve needs a few more iterations per step
  than the (linear) oscillator.
- `Float16` fails (singular Newton Jacobian), as it does throughout the nonlinear
  study.

## Results table

```@example nlpen
markdown_table(summary_table(df; panelcol = :regularization))
```

## Coarse time step (Δt = 1.0)

```@example nlpen
spec1 = pendulum_lode_spec(timespan = (0.0, 10.0), timestep = 1.0)
df1   = run_nonlinear_benchmark(spec1; timing = :quick, max_iterations = 100,
                                verbose = false, quiet = true)
nothing # hide
```

```@example nlpen
plot_convergence(df1; panelcol = :regularization, title = "Pendulum (nonlinear, Δt = 1.0)")
```

```@example nlpen
plot_energy_drift(df1; panelcol = :regularization)
```

```@example nlpen
markdown_table(summary_table(df1; panelcol = :regularization))
```

## Large time step (Δt = 10.0)

```@example nlpen
spec10 = pendulum_lode_spec(timespan = (0.0, 100.0), timestep = 10.0)
df10   = run_nonlinear_benchmark(spec10; timing = :quick, max_iterations = 100,
                                 verbose = false, quiet = true)
nothing # hide
```

```@example nlpen
plot_convergence(df10; panelcol = :regularization, title = "Pendulum (nonlinear, Δt = 10.0)")
```

```@example nlpen
markdown_table(summary_table(df10; panelcol = :regularization))
```
