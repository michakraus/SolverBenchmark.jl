# Toda Lattice (Nonlinear Integrator)

The Toda lattice (`N = 16` sites) benchmarked with the `ShallowNet` integrator
(see [Harmonic Oscillator (Nonlinear Integrator)](@ref) for the network setup and
the regularization sweep). It is built as a 16-dimensional `lodeproblem`,
so the network integrator solves a 16-dimensional implicit system at every step —
the highest-dimensional problem in this study. Its Hamiltonian depends on both `q`
and `p`; the energy drift is evaluated from the full state. No closed-form solution
exists.

The figures panel by the regularization factor ``\lambda`` — a rung of the
``\sqrt{\varepsilon(T)}`` ladder, so one panel is a different shift at each
precision; solver configurations are on the x-axis and precisions are
distinguished by colour. Results are shown at
``\Delta t = 0.1`` and repeated for ``\Delta t = 1.0`` and ``\Delta t = 10.0``
(ten steps each).

```@example nltoda
using SolverBenchmark

spec = toda_lattice_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)
df   = cached_sweep("nonlinear_toda_lattice_dt0.1") do
    run_nonlinear_benchmark(spec; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end

nothing # hide
```

## Convergence

```@example nltoda
plot_convergence(df; panelcol = :regularization, title = "Toda Lattice (nonlinear)")
```

## Nonlinear iterations

```@example nltoda
plot_iterations(df; panelcol = :regularization)
```

## Run time

```@example nltoda
plot_runtime(df; panelcol = :regularization)
```

## Energy drift

```@example nltoda
plot_energy_drift(df; panelcol = :regularization)
```

## Discussion

- Despite its dimensionality the lattice is a clean case: at `Float64`, **all four
  solvers converge at ``\lambda = 0`` and at all six rungs** — 28 of 28. The
  16-dimensional solve takes 2.6–3.0 iterations per step and conserves the energy to
  ``3.75 \dots 3.84 \times 10^{-13}``, indistinguishable between ``\lambda = 0`` and
  the rungs across a ladder spanning a factor of a thousand. Regularization is not
  needed here.
- Run times are higher than the low-dimensional examples (16 coupled network fits
  per step), which is the main cost visible here.
- **`Float32` converges at rungs 1 and 6 only** (8/28, all four solvers, at a residual
  of ``3 \times 10^{-5}``), and the other 20 rows raise the OGA initial guess's
  `SingularException`. That is the seed's marginality, not an optimum in ``\lambda``:
  the exception is raised upstream of the Newton iteration, and ``\lambda`` only
  perturbs the trajectory the next seed is built from — see
  [Harmonic Oscillator (Nonlinear Integrator)](@ref). `Float16` and `BFloat16` fail
  at every rung.

## Results table

```@example nltoda
markdown_table(summary_table(df; panelcol = :regularization))
```

## Coarse time step (Δt = 1.0)

```@example nltoda
spec1 = toda_lattice_lode_spec(timespan = (0.0, 10.0), timestep = 1.0)
df1   = cached_sweep("nonlinear_toda_lattice_dt1.0") do
    run_nonlinear_benchmark(spec1; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end
nothing # hide
```

```@example nltoda
plot_convergence(df1; panelcol = :regularization, title = "Toda Lattice (nonlinear, Δt = 1.0)")
```

```@example nltoda
markdown_table(summary_table(df1; panelcol = :regularization))
```

## Large time step (Δt = 10.0)

```@example nltoda
spec10 = toda_lattice_lode_spec(timespan = (0.0, 100.0), timestep = 10.0)
df10   = cached_sweep("nonlinear_toda_lattice_dt10.0") do
    run_nonlinear_benchmark(spec10; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end
nothing # hide
```

```@example nltoda
plot_convergence(df10; panelcol = :regularization, title = "Toda Lattice (nonlinear, Δt = 10.0)")
```

```@example nltoda
markdown_table(summary_table(df10; panelcol = :regularization))
```
