# Key Findings

A summary of what the two experiment sets actually measured, gathered in one place.
Every number below comes from the raw results the per-problem pages regenerate; the
figures and tables that support each claim are on those pages.

Measured 2026-08-10 against GeometricIntegrators 0.17, GeometricIntegratorsBase
0.5.1, SimpleSolvers 0.10.1, GeometricProblems 0.8.2 and EulerLagrange 0.5.1.
The implicit-midpoint set is twelve sweeps (six problems × two time steps) of 96
runs each; the nonlinear set is twelve sweeps (four problems × three time steps)
of 112 runs each (4 precisions × 4 solvers × 7 regularization factors).

## Solvers and line searches

- **`Newton` with a robust line search, and `DogLeg`, are the most efficient** —
  about 1.15 iterations per step averaged over the oscillator and the pendulum,
  against 2.8 for `Newton/Bisection` and 3.4 for `Picard`.
- **All six line searches are comparably robust**, and so is `DogLeg`. Over the
  twelve implicit-midpoint sweeps, 144 runs each:

  | Solver configuration | Converged |
  |:---------------------|----------:|
  | `Newton/Bisection` | 129 / 144 |
  | `DogLeg` | 117 / 144 |
  | `Newton/Static` | 114 / 144 |
  | `Newton/Backtracking` | 114 / 144 |
  | `Newton/StrongWolfe` | 114 / 144 |
  | `Newton/BierlaireQuadratic` | 113 / 144 |
  | `Newton/Quadratic` | 106 / 144 |
  | `Picard` | 44 / 144 |

  The choice between line searches matters far less than the choice of solver.
- **`Picard` is slow where it works and fails where it does not.** On the
  [Harmonic Oscillator](@ref) and [Pendulum](@ref) it converges (22/24 each) but
  needs the most iterations per step; on the Lotka–Volterra `iodeproblem`s, the
  [Double Pendulum](@ref) and the [Toda Lattice](@ref) it never converges (0/24
  each). On the Toda lattice it is the *only* failure at `Float32`/`Float64`.

## Reading the residual columns

**`Bisection` stops at the tolerance it was asked for**, where the others overshoot
it. Its residual lands right at `f_abstol`, while the remaining line searches drive
the residual one to two orders of magnitude below the requested tolerance. This is
not a defect — `Bisection` is also the most robust of the six, so the two facts are
related rather than in tension.

Read the residual columns against `f_abstol`, not against each other. Every results
table records the `f_abstol` each run was solved to and marks rows that stopped
*at* that target in an `at_tolerance` column.

That column matters most at reduced precision. The [Double Pendulum](@ref) relaxes
its tolerance to ``256\,\varepsilon(T)`` because its residual floor sits well above
``\varepsilon(T)`` — measured, at ``\approx 200 \dots 260\,\varepsilon(T)`` at
*every* precision, since the floor is set by the problem's ``O(g m l)`` force scale
rather than by the format. At `BFloat16` that tolerance is `2.0`, comparable to the
energy itself, so a converged `BFloat16` row there reports having met a target too
loose to say much.

## Precision

- **Precision sets the achievable accuracy.** On the oscillator at
  ``\Delta t = 0.1`` the energy drift is ``\approx`` `7e-17`, `1e-7`, `4e-4` and
  `4e-4` for `Float64`, `Float32`, `Float16` and `BFloat16`, while the
  discretization error (``\approx`` `1.5e-2` here) is precision-independent —
  `Float32` already reaches it.
- Over all 288 implicit-midpoint runs at each precision:

  | Precision | Converged |
  |:----------|----------:|
  | `Float64` | 263 / 288 |
  | `Float32` | 261 / 288 |
  | `Float16` | 206 / 288 |
  | `BFloat16` | 121 / 288 |

## The two 16-bit formats

`Float16` and `BFloat16` divide the same 16 bits differently — 11 significand bits
and a 5-bit exponent against 8 and 8 — so sweeping both separates a failure caused
by too few digits from one caused by too little dynamic range. They give two
distinct answers, and it is worth keeping them apart.

**On conditioning, the answer is "significand, not exponent".** Where the comparison
is not confounded by the time-grid effect below, `BFloat16` never beats `Float16`:
7/24 against 13/24 on [Lotka–Volterra (2d)](@ref) and 6/24 against 6/24 on
[Lotka–Volterra (4d)](@ref) at ``\Delta t = 0.1``, and 0/16 against 0/16 everywhere
in the nonlinear set. The stiff-system and network-Jacobian failures come from
near-singular factorizations, which need significand bits — and `BFloat16` trades
three of them away for an exponent range these problems never need.

**On the time grid, `BFloat16` has a limitation `Float16` does not.** With 8
significand bits its spacing at ``t = 100`` is `0.5`, five times a
``\Delta t = 0.1`` step, so the time series collides: `0:0.1:100` holds 1001 points
but only 451 distinct values. `HermiteExtrapolation` and `MidpointExtrapolation`
are then handed two identical times and abort for *every* solver, leaving only
`NoInitialGuess`. This is a property of the time grid, not of the solver, and it
reverses the usual trend — the oscillator goes from 8/24 at ``\Delta t = 0.1`` to
24/24 at ``\Delta t = 1.0``, the one place in this study where a larger step helps.
`Float16`, with 11 significand bits, resolves both grids.

Only compare the two formats at a ``\Delta t`` where the `BFloat16` grid resolves,
or the second effect will be mistaken for the first.

!!! note "`BFloat16` needs a compatibility layer"
    `BFloat16` is not supported by this stack out of the box: `Base` and BFloat16s
    together lack `rem`, `Integer`, `sincos` (which recurses until the stack
    overflows), two-argument `atan`, `fma` and `mod2pi`, and NaNMath — against which
    GeometricProblems writes its right-hand sides — declares its NaN-returning
    variants for `Union{Float16,Float32,Float64}` only. `src/bfloat16.jl` fills
    those gaps; it is type piracy over upstream omissions and is meant to be
    deleted as they are fixed.

## Time step

Larger time steps increase iteration counts and cause more line-search failures —
with the `BFloat16` exception above, where a larger step *fixes* the time-grid
collision.

## Nonlinear integrator set

- **Regularization is a threshold, not a tuned value.** Over the eleven measured
  sweeps, ``\lambda = 0`` converges 8 times out of 176 while each of the six rungs
  converges 23–31 times out of 176 — and the rungs are flat between themselves,
  across ladders spanning a factor of a thousand:

  | ``\lambda`` | 0 | rung 1 | rung 2 | rung 3 | rung 4 | rung 5 | rung 6 |
  |:--|--:|--:|--:|--:|--:|--:|--:|
  | Converged | 8 / 176 | 23 | 27 | 27 | **31** | 27 | 27 |

  Rung 4's slight lead is not a peak worth tuning to; where the solve is
  regularization-limited at all, every rung fixes it, and iteration count, residual
  and energy drift agree to three significant figures from rung to rung. The value to
  reach for is any nonzero one — NonlinearIntegrators' ``16\sqrt{\varepsilon(T)}``
  (rung 4, or rung 2 at `Float64`) is as good as it needs to be.
- Converged runs per sweep, out of 112. Eleven of the twelve are measured; the Toda
  lattice at ``\Delta t = 10.0`` is still running, so every aggregate below is over
  those eleven:

  | Problem | ``\Delta t = 0.1`` | ``\Delta t = 1.0`` | ``\Delta t = 10.0`` |
  |:--------|-----:|-----:|------:|
  | [Harmonic Oscillator (Nonlinear Integrator)](@ref) | 51 | 29 | 0 |
  | [Pendulum (Nonlinear Integrator)](@ref) | 47 | 0 | 0 |
  | [Double Pendulum (Nonlinear Integrator)](@ref) | 19 | 0 | 0 |
  | [Toda Lattice (Nonlinear Integrator)](@ref) | 24 | 0 | *pending* |

  ``\Delta t = 10.0`` converges nowhere on the three problems measured so far. At
  ``\Delta t = 1.0`` only the harmonic oscillator survives, with 29 — 24 of them
  `Float64` at every rung, 4 `Float32` at rung 4 alone, and 1 at ``\lambda = 0``.
- **Neither 16-bit format converges anywhere in this set** — 0/28 in every sweep, for
  both. `Float32` reaches 54/308 and `Float64` 116/308.
- **Regularization cannot rescue the reduced-precision runs, because they do not fail
  where it acts.** Of 308 rows each, `BFloat16` and `Float16` raised an exception on
  *every one* and stalled on none: not a single 16-bit run ever reached a Newton
  iteration that could be reported as non-convergent. The exception is a
  `SingularException` from `NonlinearIntegrators.initial_params!` — the ``G_k x_k = b``
  Gram solve of the **OGA initial guess**, whose third selected neuron is already
  linearly dependent on its predecessors at 16 bits. That runs before the Newton solve
  of every step, and `regularization_factor` shifts only the Newton Jacobian diagonal,
  so no rung reaches it. Fixing it means regularizing the seed's normal equations
  upstream.
- **Where ``\lambda`` does reach the solve it is decisive**, and that is `Float64`
  throughout plus `Float32` at the fine step: `Float64` stalls (rather than throws) on
  95 of 308 rows, which is the failure mode a diagonal shift addresses, and every rung
  removes it. `Float32` sits in between — 198 threw, 56 stalled.
- **A rung can be worse than no regularization at all**, which is the signature of the
  seed rather than the solver: `Float32` converges for three solvers at
  ``\lambda = 0`` on the pendulum and for none at rung 1, and on the oscillator at
  ``\Delta t = 1.0`` only rung 4 survives. The OGA guess is rebuilt from the previous
  step's solution, so ``\lambda`` perturbs the trajectory the next seed is built from
  and can push a later step's Gram matrix into rank deficiency. Read isolated
  survivals as marginality, not as an optimum in ``\lambda``.
- `Float32` LODE runs are as fast as `Float64` ones (0.004 s on the harmonic
  oscillator).
