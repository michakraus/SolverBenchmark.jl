# Double Pendulum (Nonlinear Integrator)

The double pendulum benchmarked with the `ShallowNet` integrator (see
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
df   = cached_sweep("nonlinear_double_pendulum_dt0.1") do
    run_nonlinear_benchmark(spec; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end

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

- **Regularization is not needed here either**: at `Float64` all four solvers
  converge at ``\lambda = 0`` and at every one of the six rungs, with an energy drift
  of ``2.11 \times 10^{-4}`` that is identical to three significant figures at every
  value. The solvers differ in cost, not in robustness: `Backtracking`, `StrongWolfe`
  and `DogLeg` take 3.7–5.5 iterations per step, and `Newton/Static` 6.8–8.2. The
  rungs do not change that ordering (3.9–4.4 iterations for the three at
  ``\lambda = 0``, 7.8 for `Newton/Static`).
- The chaotic dynamics give a larger energy drift than the integrable examples,
  and the achievable step size is smaller — at ``\Delta t = 1.0`` and above no
  configuration converges.
- **Only `Float64` converges at all** (28/28). `Float32`, `Float16` and `BFloat16`
  fail at every rung, and scaling ``\lambda`` to the precision does not change that.
  `Float32` stalls on 26 of its 28 rows and raises the OGA initial guess's
  `SingularException` on the other 2; `Float16` raises that exception, which runs
  before the Newton iteration `regularization_factor` acts on, and at `BFloat16` the
  integrator cannot be built — see [Harmonic Oscillator (Nonlinear Integrator)](@ref).

## Results table

```@example nldp
markdown_table(summary_table(df; panelcol = :regularization))
```

## Coarse time step (Δt = 1.0)

```@example nldp
spec1 = double_pendulum_lode_spec(timespan = (0.0, 10.0), timestep = 1.0)
df1   = cached_sweep("nonlinear_double_pendulum_dt1.0") do
    run_nonlinear_benchmark(spec1; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end
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
df10   = cached_sweep("nonlinear_double_pendulum_dt10.0") do
    run_nonlinear_benchmark(spec10; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end
nothing # hide
```

```@example nldp
plot_convergence(df10; panelcol = :regularization, title = "Double Pendulum (nonlinear, Δt = 10.0)")
```

```@example nldp
markdown_table(summary_table(df10; panelcol = :regularization))
```
