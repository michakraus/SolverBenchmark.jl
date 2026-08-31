# Shims for `BFloat16` operations that neither BFloat16s.jl nor Base defines.
#
# BFloat16s forwards most of `Base.Math` to `Float32` one function at a time, and
# `Float32(::BFloat16)` is exact (same exponent range, wider significand), so each
# shim below is the same widen-compute-round pattern and is correctly rounded.
# What is *not* covered by that forwarding list is collected here.
#
# Every one of these is type piracy, and every one is a gap upstream rather than a
# choice this package is making — delete them as BFloat16s grows the methods; see
# https://github.com/JuliaMath/BFloat16s.jl.
#
# Why this matters beyond the immediate error: `run_case`/`run_nonlinear_case` catch
# any exception and record the combination as a *non-converged row*. A missing method
# is therefore indistinguishable in the results from a genuine numerical failure, and
# would be silently reported as "`BFloat16` does not converge here". Each shim was
# added after such a failure turned out to be a missing method, not a diverging solve.

# --- reached by the range constructor ----------------------------------------
#
# `GeometricSolution` builds its `TimeSeries` as `tbegin:Δt:tend`. `BFloat16` is not
# in `Union{Float16,Float32,Float64}`, so that range does not take the twice-precision
# fast path but the generic `ArithmeticRounds` one, `StepRangeLen(start, step,
# convert(Integer, fld(stop - start, step)) + 1)` (`base/range.jl`).

# BFloat16s defines `+ - * / ^` for two `BFloat16`s but not `rem`, so `rem` — and with
# it `mod`, `div`, `fld` and `cld`, which Base derives from it — hits Base's `no_op_err`.
Base.rem(x::BFloat16, y::BFloat16) = BFloat16(rem(Float32(x), Float32(y)))

# `Integer(x)` is defined in `Core` for `Union{Float16,Float32,Float64}` only.
Base.Integer(x::BFloat16) = Int(x)

# --- reached by the problem right-hand sides ---------------------------------

# `sincos(x) = _sincos(float(x))` and `_sincos(x::AbstractFloat) = sincos(x)`
# (`base/special/trig.jl`), so an `AbstractFloat` without a concrete `sincos` method
# recurses until the stack overflows. That is what the pendulum LODE's Lagrangian hits.
Base.sincos(x::BFloat16) = BFloat16.(sincos(Float32(x)))

# Two-argument `atan`, `fma` and `mod2pi` are likewise absent (one-argument `atan`,
# `muladd`, `hypot` and `sincospi` are covered by BFloat16s and need no shim). `fma`
# via `Float32` is correctly rounded: 24 significand bits is more than the 16 an exact
# `BFloat16` product needs.
Base.atan(y::BFloat16, x::BFloat16) = BFloat16(atan(Float32(y), Float32(x)))
function Base.fma(x::BFloat16, y::BFloat16, z::BFloat16)
    BFloat16(fma(Float32(x), Float32(y), Float32(z)))
end
Base.mod2pi(x::BFloat16) = BFloat16(mod2pi(Float32(x)))

# --- NaNMath ------------------------------------------------------------------
#
# `GeometricProblems` writes its right-hand sides against NaNMath, whose NaN-returning
# variants are declared for `Union{Float16,Float32,Float64}`. Everything else reaches
# `NaNMath.f(x::Real)`, which deliberately `throw`s a `MethodError` when `float(x) === x`
# — so a `BFloat16` double pendulum fails on `NaNMath.cos` before it ever reaches a
# solver. These mirror NaNMath's own definitions with `T = BFloat16`; the guard, not
# the kernel, is the point of each one.
for (f, guard) in ((:sin, :(isinf(x))), (:cos, :(isinf(x))), (:tan, :(isinf(x))),
    (:asin, :(abs(x) > one(x))), (:acos, :(abs(x) > one(x))),
    (:atanh, :(abs(x) > one(x))), (:acosh, :(x < one(x))),
    (:log, :(x < 0)), (:log2, :(x < 0)), (:log10, :(x < 0)),
    (:log1p, :(x < -one(x))))
    @eval NaNMath.$f(x::BFloat16) = $guard ? BFloat16(NaN) : BFloat16(Base.$f(Float32(x)))
end
