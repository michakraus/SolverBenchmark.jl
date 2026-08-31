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

- Despite its dimensionality the lattice is the cleanest case in the set: at
  `Float64`, **all four solvers converge at all six rungs and none at
  ``\lambda = 0``** — 24 of 28, a perfect split on ``\lambda > 0``. The
  16-dimensional solve takes ``\approx 12`` iterations per step and conserves the
  energy to ``3.75 \times 10^{-13}``, again indistinguishable from rung to rung across
  a ladder spanning a factor of a thousand. Regularization here is purely a threshold.
- Run times are higher than the low-dimensional examples (16 coupled network fits
  per step), which is the main cost visible here.
- **Only `Float64` converges** (24/28); `Float32`, `Float16` and `BFloat16` fail at
  every rung. Scaling ``\lambda`` to the precision does not help them, because the
  exception is not the one ``\lambda`` addresses: it is raised in the OGA initial
  guess's Gram solve, upstream of the Newton iteration — see
  [Harmonic Oscillator (Nonlinear Integrator)](@ref).

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
