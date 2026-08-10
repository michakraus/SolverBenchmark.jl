```@meta
CurrentModule = SolverBenchmark
```

# Low-Precision Support

Sweeping four precisions is the point of this package, and the two 16-bit formats
are where most of the friction is. This page collects what had to be done to make
them run at all, what they can and cannot represent, and how the residual tolerance
scales. For what the sweeps actually measured, see [Key Findings](@ref).

`Float16` and `BFloat16` divide the same 16 bits differently:

| | Significand bits | Exponent bits | `eps(T)` | `floatmax(T)` |
|:--|---:|---:|---:|---:|
| `Float16` | 11 | 5 | `9.8e-4` | `6.5e4` |
| `BFloat16` | 8 | 8 | `7.8e-3` | `3.4e38` |

`BFloat16` therefore has the dynamic range of `Float32` and roughly a third of
`Float16`'s resolution. Sweeping both separates a failure caused by too few digits
from one caused by too little range — which is exactly why both are in
[`default_precisions`](@ref).

## The `BFloat16` compatibility layer

**`BFloat16` is not supported by this stack out of the box.** `src/bfloat16.jl`
fills the gaps. Every method in it is type piracy over an upstream omission, every
one is the same widen-to-`Float32`-and-round (exact, because `Float32(::BFloat16)`
is exact and `Float32` has more than twice the significand), and every one should be
deleted as [BFloat16s.jl](https://github.com/JuliaMath/BFloat16s.jl) and
[NaNMath.jl](https://github.com/JuliaMath/NaNMath.jl) grow the methods themselves.

### Reached by the range constructor

Every `GeometricSolution` builds its `TimeSeries` as the range `tbegin:Δt:tend`.
Because `BFloat16` is not a member of `Union{Float16,Float32,Float64}`, that range
does not take Julia's twice-precision fast path but the generic `ArithmeticRounds`
one, `StepRangeLen(start, step, convert(Integer, fld(stop - start, step)) + 1)`
(`base/range.jl`). That needs:

- **`Base.rem`** — BFloat16s defines `+ - * / ^` for two `BFloat16`s but not `rem`,
  so it reaches Base's `no_op_err` stub. `mod`, `div`, `fld` and `cld` are all
  derived from `rem` and follow for free.
- **`Base.Integer`** — defined in `Core` for `Union{Float16,Float32,Float64}` only.

Without these, *every* run fails.

### Reached by the problem right-hand sides

- **`Base.sincos`** — this one **recurses until the stack overflows**, rather than
  raising a `MethodError`. `base/special/trig.jl` has
  `sincos(x) = _sincos(float(x))` and `_sincos(x::AbstractFloat) = sincos(x)`, so any
  `AbstractFloat` without a concrete `sincos` loops forever. The pendulum LODE's
  Lagrangian hits it.
- **`Base.atan(y, x)`, `Base.fma`, `Base.mod2pi`.** One-argument `atan`, `muladd`,
  `hypot`, `sincospi` and `sqrt` are fine as they stand.
- **`NaNMath.{sin,cos,tan,asin,acos,atanh,acosh,log,log2,log10,log1p}`.**
  GeometricProblems writes its right-hand sides against NaNMath, whose NaN-returning
  variants are declared for `Union{Float16,Float32,Float64}`; everything else falls
  to `NaNMath.f(x::Real)`, which deliberately `throw`s a `MethodError` when
  `float(x) === x`. Hence the direct `NaNMath` dependency. Without this group four
  of the six implicit-midpoint problems appear not to converge at `BFloat16`.

Nothing *else* needed changing. ForwardDiff duals, the generic LU factorization and
all six SimpleSolvers line searches specialise on `BFloat16` as they stand.

!!! warning "These gaps are invisible in the results"
    [`run_case`](@ref) records any exception as a non-converged row, so each of the
    above first presented as "`BFloat16` does not converge on this problem" — with no
    error anywhere in the output. See
    [Errors are recorded, not raised](@ref "Errors are recorded, not raised").

## `BFloat16` cannot resolve a fine time grid

This is a real limitation rather than a missing method, and it is easy to mistake for
a solver failure.

With 8 significand bits the spacing of `BFloat16` at ``t = 100`` is `0.5` — five
times a ``\Delta t = 0.1`` step. The time series therefore collides: `0:0.1:100`
holds 1001 points but only 451 distinct values. `HermiteExtrapolation` and
`MidpointExtrapolation` are then handed two identical times and throw
`ArgumentError: t₀ and t₁ in Hermite extrapolation are identical!` — for *every*
solver. `NoInitialGuess`, which never differences times, is unaffected.

**A `BFloat16` sweep that fails exactly two of its three initial guesses is this, not
a solver problem.** `Float16`, with 11 significand bits, has spacing `0.0625` at
``t = 100`` and resolves the same grid.

Note the direction of the effect: a *larger* time step makes it better, against every
other trend in the study. The harmonic oscillator converges 8/24 at
``\Delta t = 0.1`` and 24/24 at ``\Delta t = 1.0``.

!!! tip "Only compare the 16-bit formats where the grid resolves"
    Any sweep whose ``\Delta t`` is below the `BFloat16` spacing at `tend` loses two
    of its three initial guesses for reasons unrelated to the solver. The
    ``\Delta t = 0.01`` sweeps over ``(0, 10)`` are confounded this way (spacing
    `0.0625`); the ``\Delta t = 0.1`` and ``\Delta t = 1.0`` sweeps are the honest
    comparisons.

## How the residual tolerance scales

The solver's absolute residual tolerance is `f_abstol_factor * eps(T)`, with the
factor stored per problem on [`ProblemSpec`](@ref) and defaulting to `8` — the
framework's own default (see [Solver options](@ref)).

**The factor is a property of the problem, not of the precision.** On the double
pendulum the residual floor measures ``\approx 200 \dots 260\,\varepsilon(T)`` at
*every* precision:

| Precision | `max_residual` at ``\Delta t = 0.01`` | ``\div\ \varepsilon(T)`` |
|:----------|--------------------------------------:|-------------------------:|
| `BFloat16` | 1.2 – 1.5 | 154 – 192 |
| `Float16` | 0.19 – 0.25 | 195 – 256 |
| `Float32` | 2.8e-5 – 3.1e-5 | 235 – 260 |
| `Float64` | 5.0e-14 – 5.7e-14 | 225 – 257 |

The floor is set by the problem's ``O(g m l)`` force scale, which ``\varepsilon(T)``
already tracks — so a precision-dependent factor has nothing left to compensate for.
Measured against the data, a `8`-at-16-bit / `256`-above rule is a strict loss: inert
on all four LODEs, dominated by a uniform `8` on the Toda lattice, and on the double
pendulum it drops both 16-bit formats to ``\approx`` 0/24 by turning "converged at
the floor" into "failed".

Two specs are worth knowing about:

- **The double pendulum keeps `f_abstol_factor = 256`**, and needs it: at the default
  `8` its 16-bit columns are empty (0/24 each against 5/24 and 11/24).
- **The Toda lattice does not**, and uses the framework default: `256` there buys 3
  converged runs of 96 at ``\Delta t = 0.1`` and 1 at ``\Delta t = 1.0``, while
  costing one to two orders of magnitude of residual on every run that converges
  either way.

`scripts/f_abstol_study.jl` regenerates that comparison.

!!! note "At 16-bit, a relaxed tolerance can be larger than the quantity of interest"
    `256 eps(BFloat16)` is `2.0` — comparable to the double pendulum's energy. A
    converged `BFloat16` row there has met a target too loose to say much. This is
    why every results table records the `f_abstol` each run used and flags rows that
    stopped *at* it in an `at_tolerance` column; see [`summary_table`](@ref).
