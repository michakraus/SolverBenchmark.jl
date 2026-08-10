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

The figures panel by the regularization factor ``\lambda`` — a rung of the
``\sqrt{\varepsilon(T)}`` ladder, so one panel is a different shift at each
precision; solver configurations are on the x-axis and precisions are
distinguished by colour. Results are shown at
``\Delta t = 0.1`` and repeated for ``\Delta t = 1.0`` and ``\Delta t = 10.0``
(ten steps each).

```@example nlpen
using SolverBenchmark

spec = pendulum_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)
df   = cached_sweep("nonlinear_pendulum_dt0.1") do
    run_nonlinear_benchmark(spec; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end

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

- As for the harmonic oscillator, **a nonzero regularization factor is required**,
  and any rung will do. At `Float64`, ``\lambda = 0`` converges for no solver; every
  rung converges for all four, in ``\approx 2.3`` iterations per step, conserving the
  energy to ``8.05 \times 10^{-8}`` — to three significant figures the *same* drift at
  every rung, across a ladder spanning a factor of a thousand.
- The pendulum's nonlinearity means the solve needs a few more iterations per step
  than the (linear) oscillator.
- **`Float32` converges from rung 2 up** (23/28): all four solvers at rungs 2–6, but
  three of four at ``\lambda = 0`` and **none at rung 1**. A rung that is worse than no
  regularization at all is the signature of the seed, not the solver — the OGA guess is
  rebuilt from the previous step's solution, so ``\lambda`` perturbs the trajectory it
  is built from and can push a later step's Gram matrix into rank deficiency. See
  [Harmonic Oscillator (Nonlinear Integrator)](@ref) for that mechanism.
- **Both 16-bit formats fail at every rung** (0/28 each, against 23/28 at `Float32`
  and 24/28 at `Float64`). The exception again comes from the OGA initial guess's Gram
  solve, not from the Newton Jacobian, so `regularization_factor` cannot reach it.

## Results table

```@example nlpen
markdown_table(summary_table(df; panelcol = :regularization))
```

## Coarse time step (Δt = 1.0)

```@example nlpen
spec1 = pendulum_lode_spec(timespan = (0.0, 10.0), timestep = 1.0)
df1   = cached_sweep("nonlinear_pendulum_dt1.0") do
    run_nonlinear_benchmark(spec1; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end
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
df10   = cached_sweep("nonlinear_pendulum_dt10.0") do
    run_nonlinear_benchmark(spec10; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end
nothing # hide
```

```@example nlpen
plot_convergence(df10; panelcol = :regularization, title = "Pendulum (nonlinear, Δt = 10.0)")
```

```@example nlpen
markdown_table(summary_table(df10; panelcol = :regularization))
```
