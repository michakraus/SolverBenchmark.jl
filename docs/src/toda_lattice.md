# Toda Lattice

The Toda lattice is a nonlinear chain of particles with exponential
nearest-neighbour interactions. It is built here with `hodeproblem` and a modest
lattice size ``N = 16`` (the full soliton example uses ``N = 200``, which would
make the implicit solves prohibitively expensive for a solver benchmark). The
initial positions come from a bump of width ``\mu = 0.3`` with zero initial
momenta. The Hamiltonian ``H(t, q, p)`` depends on both the coordinates and the
momenta, so the energy-drift proxy is evaluated from the full ``(q, p)`` state.

Unlike the [Double Pendulum](@ref), this problem uses the framework's default
residual tolerance ``8\,\varepsilon(T)``: it does not have the double pendulum's
raised residual floor, so relaxing the tolerance to ``256\,\varepsilon(T)`` here buys
only 3 converged runs out of 96 at ``\Delta t = 0.1`` and 1 at ``\Delta t = 1.0``,
while costing one to two orders of magnitude of residual on every run that converges
either way.

The benchmark below is regenerated at documentation build time with a single,
fast timing pass. See the driver script `scripts/midpoint_toda_lattice.jl` for accurate
`BenchmarkTools` measurements. The results are shown first for the standard step
``\Delta t = 0.1`` and then repeated for a coarse step ``\Delta t = 1.0`` (see
[Coarse time step (Δt = 1.0)](@ref toda_lattice_dt1)).

```@example toda
using SolverBenchmark

spec = toda_lattice_spec(timespan = (0.0, 100.0), timestep = 0.1)
df   = run_benchmark(spec; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

## Convergence

```@example toda
plot_convergence(df; title = "Toda Lattice")
```

## Nonlinear iterations

Mean number of nonlinear-solver iterations per time step (converged runs only):

```@example toda
plot_iterations(df)
```

## Run time

```@example toda
plot_runtime(df)
```

## Energy drift

Drift of the conserved energy ``H(t, q, p)`` of the Toda lattice:

```@example toda
plot_energy_drift(df)
```

## Discussion

- The 16-dimensional implicit solve is the most expensive of the examples, so
  the run-time differences between solver configurations are more pronounced.
- **`Float16`, `Float32` and `Float64` are indistinguishable in convergence**
  (21/24 each at ``\Delta t = 0.1``): despite being the highest-dimensional
  problem of the set, the Toda lattice is well conditioned, and the three failures
  in each column are `Picard`, which never converges here.
- **`BFloat16` reaches only 7/24 at ``\Delta t = 0.1`` but 21/24 at
  ``\Delta t = 1.0``**, matching the other three. The difference is not the
  solver but the time grid: at the finer step `BFloat16` cannot represent
  ``(0, 100)`` in increments of `0.1`, so the extrapolating initial guesses fail
  (see [Harmonic Oscillator](@ref)).
- No closed-form solution is available, so accuracy is judged solely through the
  energy drift, which scales with the floating point precision.

## Results table

```@example toda
markdown_table(summary_table(df))
```

## [Coarse time step (Δt = 1.0)](@id toda_lattice_dt1)

With a ten times larger step the nonlinear solves per step become harder, which
stresses the solvers more than the ``\Delta t = 0.1`` results above.

```@example toda
spec1 = toda_lattice_spec(timespan = (0.0, 100.0), timestep = 1.0)
df1   = run_benchmark(spec1; timing = :quick, verbose = false, quiet = true)

nothing # hide
```

### Convergence

```@example toda
plot_convergence(df1; title = "Toda Lattice (Δt = 1.0)")
```

### Nonlinear iterations

```@example toda
plot_iterations(df1)
```

### Run time

```@example toda
plot_runtime(df1)
```

### Energy drift

```@example toda
plot_energy_drift(df1)
```

### Results table

```@example toda
markdown_table(summary_table(df1))
```
