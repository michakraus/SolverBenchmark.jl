# Key Findings

A summary of what the two experiment sets actually measured, gathered in one place.
Every number below comes from the raw results the per-problem pages regenerate; the
figures and tables that support each claim are on those pages.

Measured 2026-11-01 with Julia 1.13.3 against GeometricIntegrators 0.18.7,
GeometricIntegratorsBase 0.6.10, SimpleSolvers 0.14.3, GeometricProblems 0.9.2,
NonlinearIntegrators 0.5.0 and EulerLagrange 0.5.3.
The implicit-midpoint set is twelve sweeps (six problems × two time steps) of 96
runs each; the nonlinear set is twelve sweeps (four problems × three time steps)
of 112 runs each (4 precisions × 4 solvers × 7 regularization factors).

## Solvers and line searches

- **`Newton` with a robust line search, and `DogLeg`, are the most efficient** —
  about 1.4 iterations per step averaged over the oscillator and the pendulum,
  against 3.2 for `Newton/Bisection`.
- **All six line searches are comparably robust**, and so is `DogLeg`. Over the
  twelve implicit-midpoint sweeps, 144 runs each:

  | Solver configuration | Converged |
  |:---------------------|----------:|
  | `Newton/Bisection` | 119 / 144 |
  | `Newton/StrongWolfe` | 107 / 144 |
  | `Newton/Backtracking` | 106 / 144 |
  | `DogLeg` | 106 / 144 |
  | `Newton/BierlaireQuadratic` | 105 / 144 |
  | `Newton/Static` | 101 / 144 |
  | `Newton/Quadratic` | 97 / 144 |
  | `Picard` | 1 / 144 |

  The choice between line searches matters far less than the choice of solver.
- **`Picard` converges nowhere.** Its one converged row is `BFloat16` on the
  [Harmonic Oscillator](@ref) at ``\Delta t = 1.0``, inside a tolerance of `0.0625`.
  Of the other 143 rows, 57 raise an exception and 86 run to the end of the time span
  without meeting the tolerance: at `Float64` on the oscillator it takes 2.0 to 2.05
  iterations per step and leaves a residual of `2.2e-4` to `0.25`. On the
  [Toda Lattice](@ref) it is the *only* failure at `Float32`/`Float64`, and over all
  twelve sweeps it is 36 of the 40 failures at `Float64`.

## Reading the residual columns

**`Bisection` stops at the tolerance it was asked for**, where the others stop short of
it. Its median residual over the converged runs is `0.98` times `f_abstol`, against
`0.60` to `0.88` times `f_abstol` for the other configurations. This is not a defect —
`Bisection` is also the most robust of the six, so the two facts are related rather
than in tension.

Read the residual columns against `f_abstol`, not against each other. Every results
table records the `f_abstol` each run was solved to and marks rows that stopped
*at* that target in an `at_tolerance` column.

That column matters most at reduced precision. The [Double Pendulum](@ref) relaxes
its tolerance to ``256\,\varepsilon(T)`` because its residual floor sits well above
``\varepsilon(T)`` — measured, at ``\approx 200 \dots 256\,\varepsilon(T)`` at
*every* precision, since the floor is set by the problem's ``O(g m l)`` force scale
rather than by the format. At `BFloat16` that tolerance is `2.0`, comparable to the
energy itself, so a converged `BFloat16` row there reports having met a target too
loose to say much.

## Precision

- **Precision sets the achievable accuracy.** On the oscillator at
  ``\Delta t = 0.1`` the median energy drift is ``\approx`` `7e-17`, `1.3e-7`, `4.4e-4`
  and `3.9e-3` for `Float64`, `Float32`, `Float16` and `BFloat16`, while the
  discretization error (``\approx`` `1.47e-2` here) is precision-independent —
  `Float32` already reaches it.
- Over all 288 implicit-midpoint runs at each precision:

  | Precision | Converged |
  |:----------|----------:|
  | `Float64` | 248 / 288 |
  | `Float32` | 247 / 288 |
  | `Float16` | 147 / 288 |
  | `BFloat16` | 100 / 288 |

## The two 16-bit formats

`Float16` and `BFloat16` divide the same 16 bits differently — 11 significand bits
and a 5-bit exponent against 8 and 8 — so sweeping both separates a failure caused
by too few digits from one caused by too little dynamic range. They give two
distinct answers, and it is worth keeping them apart.

**On conditioning, the answer is "significand, not exponent".** Where the comparison
is not confounded by the time-grid effect below, `BFloat16` never beats `Float16`:
2/24 against 7/24 on [Lotka–Volterra (2d)](@ref) and 4/24 against 4/24 on
[Lotka–Volterra (4d)](@ref) at ``\Delta t = 0.1``. The stiff-system failures come
from near-singular factorizations, which need significand bits — and `BFloat16`
trades three of them away for an exponent range these problems never need.

**On the time grid, `BFloat16` has a limitation `Float16` does not.** With 8
significand bits its spacing at ``t = 100`` is `0.5`, five times a
``\Delta t = 0.1`` step, so the time series collides: `0:0.1:100` holds 1001 points
but only 451 distinct values. `HermiteExtrapolation` and `MidpointExtrapolation`
are then handed two identical times and abort for *every* solver, leaving only
`NoInitialGuess`. This is a property of the time grid, not of the solver, and it
reverses the usual trend — the oscillator goes from 7/24 at ``\Delta t = 0.1`` to
22/24 at ``\Delta t = 1.0``, the one place in this study where a larger step helps.
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

Larger time steps increase iteration counts: at `Float32`/`Float64`, `Newton` takes
2.3 iterations per step on the pendulum at ``\Delta t = 0.1`` and 3.4 at
``\Delta t = 1.0``, and the Toda lattice, the double pendulum and both Lotka–Volterra
systems rise by a similar amount. The linear oscillator is the exception (1.65
against 1.3). At these precisions the convergence count barely moves with the step;
the `BFloat16` exception above is where a larger step *fixes* the time-grid
collision.

## Nonlinear integrator set

- **The Newton solve does not need regularization.** NonlinearIntegrators takes the
  minimum-norm step of a rank-revealing solve, so the near-singular network Jacobian
  does not stop the iteration. At `Float64`, ``\lambda = 0`` converges wherever a rung
  does: every cell of four solvers is 4/4 at ``\lambda = 0`` and at all six rungs on
  the four problems at ``\Delta t = 0.1`` and on the oscillator at
  ``\Delta t = 1.0``. Over the twelve sweeps, 192 rows per value:

  | ``\lambda`` | 0 | rung 1 | rung 2 | rung 3 | rung 4 | rung 5 | rung 6 |
  |:--|--:|--:|--:|--:|--:|--:|--:|
  | Converged | 24 | 29 | 24 | 28 | 24 | 24 | 28 |

  The differences between the columns come from `Float32` (rung 1, 3 and 6, see
  below) and from one marginal `Float64` row (the oscillator at ``\Delta t = 10.0``,
  `Newton/Static`, rung 1), not from the Newton solve.
- **At `Float64` the shift changes the cost, not the outcome.** Mean Newton iterations
  per step at ``\lambda = 0`` and over the six rungs, and the solution quality:

  | Problem, ``\Delta t`` | ``\lambda = 0`` | rungs 1–6 | Accuracy or energy drift |
  |:--|--:|--:|:--|
  | Harmonic oscillator, 0.1 | 1.2 | 1.0 – 2.4 | accuracy `1.44e-13`; `1.1e-14` – `1.43e-13` at the rungs |
  | Harmonic oscillator, 1.0 | 3.0 | 3.0 – 3.8 | accuracy `1.53e-6` at every value |
  | Pendulum, 0.1 | 2.0 | 2.0 – 3.0 | drift `8.05e-8` at every value |
  | Double pendulum, 0.1 | 3.9 – 7.8 | 3.7 – 8.2 | drift `2.11e-4` at every value |
  | Toda lattice, 0.1 | 2.6 – 2.9 | 2.7 – 3.0 | drift `3.75e-13` – `3.84e-13` |

  Regularization does not help at any rung. On the oscillator at ``\Delta t = 0.1``
  the upper rungs cost iterations — rungs 3–6 take 2.1–2.4 per step against 1.2 at
  ``\lambda = 0`` — and elsewhere the counts agree to within the spread between
  solvers.
- Converged runs per sweep, out of 112:

  | Problem | ``\Delta t = 0.1`` | ``\Delta t = 1.0`` | ``\Delta t = 10.0`` |
  |:--------|-----:|-----:|------:|
  | [Harmonic Oscillator (Nonlinear Integrator)](@ref) | 56 | 32 | 1 |
  | [Pendulum (Nonlinear Integrator)](@ref) | 28 | 0 | 0 |
  | [Double Pendulum (Nonlinear Integrator)](@ref) | 28 | 0 | 0 |
  | [Toda Lattice (Nonlinear Integrator)](@ref) | 36 | 0 | 0 |

  ``\Delta t = 10.0`` converges once in 448 runs. At ``\Delta t = 1.0`` only the
  harmonic oscillator survives, with 32 — 28 of them `Float64` at ``\lambda = 0`` and
  every rung, and 4 `Float32` at rung 3 alone. On the coarse steps 150 of the 195
  failed `Float64` rows stall above the tolerance. The other 45 raise an exception:
  29 on the double pendulum are a `DomainError`, raised when its trigonometric
  right-hand side receives an infinite angle, and 16 are the OGA `SingularException`
  described below.
- **Neither 16-bit format converges anywhere in this set** — 0/28 in every sweep, for
  both. `Float32` reaches 40/336 and `Float64` 141/336.
- **The 16-bit formats fail before the Newton solve.** Of 336 rows each, `BFloat16`
  and `Float16` raise an exception on *every one*: not a single 16-bit run reaches a
  Newton iteration that could be reported as non-convergent, so ``\lambda`` cannot act
  on them.
  - At `BFloat16` the integrator cannot be built. `NetworkIntegratorCore` reshapes
    the range `0:1/10:1` into 11 columns, and in `BFloat16` that range has 10
    elements, so the constructor raises a `DimensionMismatch`.
  - At `Float16` the exception is a `SingularException` from
    `NonlinearIntegrators.initial_params!` — the ``G_k x_k = b`` Gram solve of the
    **OGA initial guess**, whose selected neurons are linearly dependent at 16 bits.
    That runs before the Newton solve of every step, and `regularization_factor`
    shifts only the Newton Jacobian, so no rung reaches it. On the double pendulum at
    ``\Delta t = 10.0`` the `Float16` rows raise the infinite-angle `DomainError`
    instead.
- **`Float32` is limited by the same seed, not by the Newton solve.** 181 of its 296
  failed rows raise the OGA `SingularException`, and the other 115 stall. Where it
  converges, ``\lambda`` decides it in no consistent way: on the oscillator at
  ``\Delta t = 0.1`` all seven values converge, at ``\Delta t = 1.0`` only rung 3,
  and on the Toda lattice at ``\Delta t = 0.1`` only rungs 1 and 6. The OGA guess is
  rebuilt from the previous step's solution, so ``\lambda`` perturbs the trajectory
  the next seed is built from and decides by chance whether a later step's Gram
  matrix stays full-rank. Read these isolated survivals as marginality, not as an
  optimum in ``\lambda``.
- `Float32` LODE runs are as fast as `Float64` ones (0.0063 s against 0.0067 s on the
  harmonic oscillator).
