# Harmonic Oscillator (Nonlinear Integrator)

This page benchmarks the neural-network variational integrator `ShallowNet` from
[NonlinearIntegrators.jl](https://github.com/JuliaGNI/NonlinearIntegrators.jl) on
the harmonic oscillator, built as a Lagrangian problem (`lodeproblem`). The
integrator represents the trajectory over one time step with a one-layer network
(`S = 4` neurons, activation ``x \mapsto \max(0,x)^3``) and enforces the discrete
variational principle with an `R = 8`-point Gauss–Legendre quadrature; the network
parameters are seeded with its built-in greedy (`OGA1dNormalEquations`) initial
guess.

Unlike the [implicit midpoint](@ref "Harmonic Oscillator") analyses, this sweep
varies the nonlinear solver's **regularization factor** ``\lambda`` (a
Levenberg–Marquardt-style shift added to the Newton Jacobian diagonal) in place of
the initial guess, because the network Jacobian is *near-singular*. NonlinearIntegrators
takes the minimum-norm step of a rank-revealing solve, so Newton converges without
the shift as well; the sweep measures what the shift costs or buys at each
precision. The swept options are:

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

- **Regularization is not needed.** At ``\lambda = 0`` the `Float64` Newton iteration
  converges for all four solvers in 1.2 iterations per step, with residual
  ``4.4 \times 10^{-14}`` and accuracy ``1.44 \times 10^{-13}``. The six rungs, across
  a ladder spanning ``6 \times 10^{-8}`` to ``6 \times 10^{-5}``, converge as well and
  do not improve on it: rungs 1 and 2 take 1.0–1.5 iterations per step, and rungs 3–6
  take 2.1–2.4, with residuals of ``4 \dots 9 \times 10^{-14}``. The accuracy is
  ``1.41 \dots 1.43 \times 10^{-13}`` at rungs 3–6 (``6.6 \times 10^{-14}`` for
  `DogLeg` at rung 3) and ``1.1 \times 10^{-14}`` to
  ``9.4 \times 10^{-14}`` at rungs 1 and 2, all at the same order as the energy drift
  (``3.3 \dots 7.6 \times 10^{-14}``).
- **The choice of line search barely matters**: all of `Static`, `Backtracking`,
  `StrongWolfe` and `DogLeg` take the same number of iterations at each value of
  ``\lambda``, to within 0.2 per step, because the Newton step is already close to
  optimal.
- **Both 16-bit formats fail, and regularization cannot reach the reason.** No
  configuration converges at `Float16` or `BFloat16` (0/28 each), at any rung, and
  neither failure is in the Newton solve. At `BFloat16` the integrator cannot be
  built: `NetworkIntegratorCore` reshapes the range `0:1/10:1` into 11 columns, and in
  `BFloat16` that range has 10 elements, so the constructor raises a
  `DimensionMismatch`. At `Float16` the failure is a `SingularException` raised in
  `NonlinearIntegrators.initial_params!`, by the ``G_k x_k = b`` Gram solve of the
  **OGA initial guess**, whose selected neurons are linearly dependent at 16 bits.
  That runs before the Newton iteration of every step, and `regularization_factor`
  shifts only the Newton Jacobian diagonal, so no rung of the ladder can lift it.
  Lifting it would mean regularizing the seed's normal equations upstream.
- **`Float32` reaches its residual floor** (``\approx 1.9 \times 10^{-5}``) in one
  iteration per step and is reported as converged under the relaxed tolerance used for
  this problem (``256\,\varepsilon``); its accuracy against the analytic solution is
  ``4 \dots 7 \times 10^{-7}``. All four solvers converge at ``\lambda = 0`` and at
  every rung, so at this step size `Float32` is not regularization-limited at all.
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
binding constraint: it converges at **rung 3 only** — and there for all four solvers,
with the same residual ``4.6 \times 10^{-6}`` — while every other rung, and
``\lambda = 0``, raises the OGA `SingularException` described above. That is not a
sweet spot in ``\lambda``. The seed is re-run at every step from the previous step's
solution, so a different ``\lambda`` perturbs the trajectory that the next seed is
built from, and which value happens to keep the Gram matrix full-rank for all ten
steps is incidental. Read it as "`Float32` is marginal here", not as "``8\sqrt\varepsilon``
is optimal here". `Float64` converges for all four solvers at ``\lambda = 0`` and at
every rung, in 3.0–3.8 iterations per step and with the same accuracy
``1.53 \times 10^{-6}``.

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
