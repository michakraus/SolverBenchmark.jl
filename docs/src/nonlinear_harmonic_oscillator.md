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
| Precision | `BFloat16`, `Float16`, `Float32`, `Float64` |
| Solver | `Newton/Static`, `Newton/Backtracking`, `Newton/StrongWolfe`, `DogLeg` |
| Regularization ``\lambda`` | ``0``, and rungs 1–6 of the ``\sqrt{\varepsilon(T)}`` ladder |

Each run integrates **ten time steps**, and the three step sizes
``\Delta t = 0.1, 1.0, 10.0`` therefore span ``(0,1)``, ``(0,10)`` and ``(0,100)``.
The figures below panel by ``\lambda``; within each panel the solver
configurations are on the x-axis and the precisions are distinguished by colour.

!!! note "A rung is a different number at each precision"
    ``\lambda`` is swept as multiples of ``\sqrt{\varepsilon(T)}``, not as absolute
    values, so that the shift is scaled to the precision it protects. Rung 4 is
    ``16\sqrt{\varepsilon(T)}`` — `0.5` at `Float16`, `5.5e-3` at `Float32` — and the
    `Float64` ladder is stretched to ``2^k`` with ``k = 2, 4, \dots, 12``, where rung 2
    is the same ``16\sqrt\varepsilon``. [How the regularization factor scales](@ref)
    has the full table; each row's own value is in the results CSV.

The benchmark is regenerated at documentation build time with a single, fast
timing pass. See the driver script `scripts/nonlinear_harmonic_oscillator.jl` for
accurate `BenchmarkTools` measurements.

```@example nlho
using SolverBenchmark

spec = harmonic_oscillator_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)
df   = cached_sweep("nonlinear_harmonic_oscillator_dt0.1") do
    run_nonlinear_benchmark(spec; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end

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

- **Regularization is essential, and it is a threshold rather than a tuned value.**
  At ``\lambda = 0`` the `Float64` Newton iteration converges for *no* solver: it
  runs out its 1000-iteration budget at a residual of ``\approx 3 \times 10^{-12}``,
  above the tolerance, because the network parameterization makes the Jacobian
  near-singular. Every one of the six rungs fixes it, and they are
  indistinguishable from each other — 2.0–2.2 iterations per step, residual
  ``\approx 5 \times 10^{-14}``, accuracy ``1.41`` to
  ``1.44 \times 10^{-13}`` across a ladder spanning
  ``6 \times 10^{-8}`` to ``6 \times 10^{-5}``, a factor of a thousand. Nothing in
  this range over-damps; ``\lambda`` only has to be nonzero.
- **The choice of line search barely matters** once regularization is on: all of
  `Static`, `Backtracking`, `StrongWolfe` and `DogLeg` behave almost identically,
  because the regularized Newton step is already close to optimal.
- **Both 16-bit formats fail, and regularization cannot reach the reason.** No
  configuration converges at `Float16` or `BFloat16` (0/28 each), at any rung. The
  failure is a `SingularException` — but not from the Newton Jacobian. It is raised
  in `NonlinearIntegrators.initial_params!`, by the ``G_k x_k = b`` Gram solve of the
  **OGA initial guess**, whose third selected neuron is already linearly dependent on
  its predecessors at 16 bits. That runs before the Newton iteration of every step,
  and `regularization_factor` shifts only the Newton Jacobian diagonal, so no rung of
  the ladder can lift it. Lifting it would mean regularizing the seed's normal
  equations upstream. `BFloat16`'s wider exponent does not help — the obstacle is
  conditioning, which wants significand bits, and it has three fewer than `Float16`.
- **`Float32` reaches its residual floor** (``\approx 3 \times 10^{-5}``) in about one
  iteration per step and is reported as converged under the relaxed tolerance used for
  this problem (``256\,\varepsilon``); its accuracy against the analytic solution is
  ``\approx 5 \times 10^{-7}``. Here ``\lambda = 0`` converges too — for three of the
  four solvers — so at this step size `Float32` is not regularization-limited at all.
- **The OGA dictionary size** (`dict_amount`) has little effect on accuracy here: a
  few hundred candidate neurons match the reference's several hundred thousand,
  while being markedly faster. The dictionary is assembled in double precision, so
  it neither limits nor rescues the reduced-precision runs.

## Results table

```@example nlho
markdown_table(summary_table(df; panelcol = :regularization))
```

## Coarse time step (Δt = 1.0)

The same benchmark with a ten-times-larger step (still ten steps, so ``(0,10)``).

At this step size `Float32` shows how indirectly ``\lambda`` acts once the seed is the
binding constraint: it converges at **rung 4 only** — and there for all four solvers,
with the same residual ``5.5 \times 10^{-6}`` — while every other rung, and
``\lambda = 0``, raises the OGA `SingularException` described above. That is not a
sweet spot in ``\lambda``. The seed is re-run at every step from the previous step's
solution, so a different ``\lambda`` perturbs the trajectory that the next seed is
built from, and which value happens to keep the Gram matrix full-rank for all ten
steps is incidental. Read it as "`Float32` is marginal here", not as "``16\sqrt\varepsilon``
is optimal here".

```@example nlho
spec1 = harmonic_oscillator_lode_spec(timespan = (0.0, 10.0), timestep = 1.0)
df1   = cached_sweep("nonlinear_harmonic_oscillator_dt1.0") do
    run_nonlinear_benchmark(spec1; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end

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
df10   = cached_sweep("nonlinear_harmonic_oscillator_dt10.0") do
    run_nonlinear_benchmark(spec10; timing = :quick, max_iterations = 100,
                            verbose = false, quiet = true)
end

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
