# Double Pendulum (Nonlinear Integrator)

The double pendulum benchmarked with the `NonLinear_OneLayer_GML` integrator (see
[Harmonic Oscillator (Nonlinear Integrator)](@ref) for the network setup and the
regularization sweep). It is built as a two-dimensional `lodeproblem`; being
chaotic and strongly nonlinear, it is a demanding test for the implicit network
solve. Its Hamiltonian depends on both `q` and `p`, so the energy drift is
evaluated from the full state. No closed-form solution exists.

The figures panel by the regularization factor ``\lambda`` — a rung of the
``\sqrt{\varepsilon(T)}`` ladder, so one panel is a different shift at each
precision; solver configurations are on the x-axis and precisions are
distinguished by colour. Results are shown at
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

- **Regularization is again decisive**, and again flat across the ladder: at
  `Float64`, `Backtracking` and `StrongWolfe` converge at every one of the six rungs
  and at none of them for ``\lambda = 0``, taking ``\approx 15`` iterations per step
  with an energy drift of ``2.11 \times 10^{-4}`` that is identical to three
  significant figures at every rung. `DogLeg` (a trust-region method) is the most
  robust here — it is the only configuration that makes progress even at
  ``\lambda = 0``, and `Newton/Static` converges nowhere at any rung. That is the
  clearest ordering of the four solver configurations anywhere in the study.
- The chaotic dynamics give a larger energy drift than the integrable examples,
  and the achievable step size is smaller — at ``\Delta t = 1.0`` and above the
  solve struggles.
- **Only `Float64` converges at all** (19/28). `Float32`, `Float16` and `BFloat16`
  fail at every rung, and scaling ``\lambda`` to the precision does not change that:
  the exception is raised in the OGA initial guess's Gram solve, which runs before the
  Newton iteration `regularization_factor` acts on — see
  [Harmonic Oscillator (Nonlinear Integrator)](@ref).

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
