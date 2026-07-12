# Harmonic Oscillator (Nonlinear Integrator)

This page benchmarks the neural-network variational integrator
`NonLinear_OneLayer_GML` from
[NonlinearIntegrators.jl](https://github.com/JuliaGNI/NonlinearIntegrators.jl) on
the harmonic oscillator, built as a Lagrangian problem (`lodeproblem`). The
integrator represents the trajectory over one time step with a one-layer network
(`S = 4` neurons, activation ``x \mapsto \max(0,x)^3``) and enforces the discrete
variational principle with an `R = 8`-point Gauss–Legendre quadrature; the network
parameters are seeded with its built-in greedy (`OGA1d`) initial guess.

Unlike the [implicit midpoint](@ref "Harmonic Oscillator") analyses, this sweep
varies the nonlinear solver's **regularization factor** ``\lambda`` (a
Levenberg–Marquardt-style shift added to the Newton Jacobian diagonal) in place of
the initial guess, because the network solve is *near-singular* — without
regularization Newton does not converge. The swept options are:

| Dimension | Values |
|:----------|:-------|
| Precision | `Float16`, `Float32`, `Float64` |
| Solver | `Newton/Static`, `Newton/Backtracking`, `Newton/StrongWolfe`, `DogLeg` |
| Regularization ``\lambda`` | `0`, `1e-3`, `1e-5`, `1e-7` |

Each run integrates **ten time steps**, and the three step sizes
``\Delta t = 0.1, 1.0, 10.0`` therefore span ``(0,1)``, ``(0,10)`` and ``(0,100)``.
The figures below panel by ``\lambda``; within each panel the solver
configurations are on the x-axis and the precisions are distinguished by colour.

The benchmark is regenerated at documentation build time with a single, fast
timing pass. See the driver script `scripts/nonlinear_harmonic_oscillator.jl` for
accurate `BenchmarkTools` measurements.

```@example nlho
using SolverBenchmark

spec = harmonic_oscillator_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)
df   = run_nonlinear_benchmark(spec; timing = :quick, max_iterations = 100,
                               verbose = false, quiet = true)

nothing # hide
```

## Convergence

Which combinations reached the solver tolerance at every time step (green), and
which failed (red):

```@example nlho
plot_convergence(df; panelcol = :regularization, title = "Harmonic Oscillator (LODE)")
```

## Nonlinear iterations

Mean number of nonlinear-solver iterations per time step (converged runs only):

```@example nlho
plot_iterations(df; panelcol = :regularization)
```

## Run time

```@example nlho
plot_runtime(df; panelcol = :regularization)
```

## Energy drift

Drift of the conserved energy ``|H(t_\text{end}) - H(0)|``:

```@example nlho
plot_energy_drift(df; panelcol = :regularization)
```

## Accuracy

Maximum error against the analytic solution:

```@example nlho
plot_accuracy(df; panelcol = :regularization)
```

## Discussion

- **Regularization is essential.** With ``\lambda = 0`` the Newton iteration does
  not converge for *any* solver — the network parameterization makes the Jacobian
  near-singular, so the step stalls at a residual floor well above the tolerance.
  A small ``\lambda`` (``10^{-3}`` to ``10^{-7}``) regularizes the Jacobian and the
  solve converges in only a few iterations per step, to an accuracy of
  ``\approx 10^{-13}`` at `Float64`.
- **The choice of line search barely matters** once regularization is on: all of
  `Static`, `Backtracking`, `StrongWolfe` and `DogLeg` behave almost identically,
  because the regularized Newton step is already close to optimal.
- **`Float16` fails.** Half precision cannot factor the (regularized) network
  Jacobian — the LU factorization is singular — so no configuration converges at
  `Float16`, regardless of ``\lambda``. These runs are recorded as failures.
- **`Float32` reaches its residual floor** (``\approx 10^{-5}``) and is reported as
  converged under the relaxed tolerance used for this problem
  (``256\,\varepsilon``); its accuracy against the analytic solution is
  ``\approx 10^{-6}``.
- **The OGA dictionary size** (`dict_amount`) has little effect on accuracy here: a
  few hundred candidate neurons match the reference's several hundred thousand,
  while being markedly faster. The dictionary is assembled in double precision, so
  it neither limits nor rescues the reduced-precision runs.

## Results table

```@example nlho
markdown_table(summary_table(df; panelcol = :regularization))
```

## Coarse time step (Δt = 1.0)

The same benchmark with a ten-times-larger step (still ten steps, so ``(0,10)``):

```@example nlho
spec1 = harmonic_oscillator_lode_spec(timespan = (0.0, 10.0), timestep = 1.0)
df1   = run_nonlinear_benchmark(spec1; timing = :quick, max_iterations = 100,
                                verbose = false, quiet = true)

nothing # hide
```

```@example nlho
plot_convergence(df1; panelcol = :regularization, title = "Harmonic Oscillator (LODE, Δt = 1.0)")
```

```@example nlho
plot_accuracy(df1; panelcol = :regularization)
```

```@example nlho
markdown_table(summary_table(df1; panelcol = :regularization))
```

## Large time step (Δt = 10.0)

With ``\Delta t = 10.0`` the ten steps span ``(0,100)`` — many oscillation periods
per step, a demanding test for the network representation:

```@example nlho
spec10 = harmonic_oscillator_lode_spec(timespan = (0.0, 100.0), timestep = 10.0)
df10   = run_nonlinear_benchmark(spec10; timing = :quick, max_iterations = 100,
                                 verbose = false, quiet = true)

nothing # hide
```

```@example nlho
plot_convergence(df10; panelcol = :regularization, title = "Harmonic Oscillator (LODE, Δt = 10.0)")
```

```@example nlho
plot_accuracy(df10; panelcol = :regularization)
```

```@example nlho
markdown_table(summary_table(df10; panelcol = :regularization))
```
