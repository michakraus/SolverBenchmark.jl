"""
    SolverConfig

A single nonlinear-solver configuration to be benchmarked: a solver method from
`SimpleSolvers.jl` together with an optional line search.

# Fields
- `solver_name::String`: name of the solver method (e.g. `"Newton"`).
- `linesearch_name::String`: name of the line search, or `""` if none applies.
- `solver`: a `SimpleSolvers.NonlinearSolverMethod` instance (e.g. `Newton()`).
- `linesearch`: a callable `T -> LinesearchMethod` (line-search constructors are
  precision-typed, e.g. `Backtracking(T)`), or `nothing`.

`Newton` supports a line search; `DogLeg` and `Picard` do not (they must be
constructed with `linesearch = nothing`).
"""
struct SolverConfig
    solver_name::String
    linesearch_name::String
    solver::Any
    linesearch::Union{Function,Nothing}
end

"""
    solver_label(cfg::SolverConfig)

A compact label combining solver and line-search name, e.g. `"Newton/Backtracking"`
or `"DogLeg"`.
"""
solver_label(cfg::SolverConfig) =
    isempty(cfg.linesearch_name) ? cfg.solver_name : "$(cfg.solver_name)/$(cfg.linesearch_name)"

"""
    precision_label(T)

The name of the precision type `T` as it appears in the `precision` column of a
benchmark `DataFrame`, e.g. `"Float64"` or `"BFloat16"`.

`nameof` rather than `string`: Julia renders a type module-qualified whenever its
module is not visible from `Main`, so `string(BFloat16)` yields
`"BFloat16s.BFloat16"` outside a session that did `using BFloat16s` — for instance
inside a Documenter `@example` sandbox. The plotting code matches this column
against `_PRECISION_ORDER` by string equality and silently drops rows that do not
match, so the label has to be independent of where it is produced.
"""
precision_label(::Type{T}) where {T} = string(nameof(T))

"""
    default_solver_configs()

Return the default list of [`SolverConfig`](@ref)s: `Newton` combined with each
of the six line searches (`Static`, `Backtracking`, `Bisection`, `Quadratic`,
`BierlaireQuadratic`, `StrongWolfe`), plus `DogLeg` and `Picard` (which take no
line search) — eight configurations in total.
"""
function default_solver_configs()
    linesearches = [
        ("Static",             Static),
        ("Backtracking",       Backtracking),
        ("Bisection",          Bisection),
        ("Quadratic",          Quadratic),
        ("BierlaireQuadratic", BierlaireQuadratic),
        ("StrongWolfe",        StrongWolfe),
    ]

    configs = SolverConfig[]
    for (name, LS) in linesearches
        push!(configs, SolverConfig("Newton", name, Newton(), T -> LS(T)))
    end
    push!(configs, SolverConfig("DogLeg", "", DogLeg(), nothing))
    push!(configs, SolverConfig("Picard", "", Picard(), nothing))
    configs
end

"""
    InitialGuessConfig

An initial-guess (extrapolation) configuration for the integrator.

# Fields
- `name::String`: label of the initial guess.
- `build`: callable `() -> initial guess`, returning an `Extrapolation` or
  `InitialGuess` instance.
"""
struct InitialGuessConfig
    name::String
    build::Function
end

"""
    RegularizationConfig

A `regularization_factor` configuration for the nonlinear solver: the
Levenberg–Marquardt-style shift SimpleSolvers adds to the Newton Jacobian diagonal
before factorizing it.

# Fields
- `name::String`: panel label of the configuration (`"λ = 0"`, `"λ rung 1"`, …).
- `rung::Union{Int,Nothing}`: position on the precision-scaled ladder, or `nothing`
  for a configuration whose value is the same at every precision.
- `factor::Function`: callable `T -> value`, the shift at working precision `T`.

**The value is a function of `T`, not a number.** The shift has to be scaled to the
precision it protects: `1e-7` is a meaningful nudge to a `Float64` Jacobian and pure
noise to a `Float16` one, whose own `√eps` is already `0.03`. See
[`scaled_regularization`](@ref) for the ladder and
[`nonlinear_regularization_factors`](@ref) for the list that is swept.
"""
struct RegularizationConfig
    name::String
    rung::Union{Int,Nothing}
    factor::Function
end

"""
    regularization_label(λ)

Compact panel label for a fixed regularization factor: `"λ = 0"`, `"λ = 1e-3"`.
The rungs of the precision-scaled ladder are labelled by position instead — their
numeric value depends on the precision, and a benchmark `DataFrame` holds all four
at once (see [`scaled_regularization`](@ref)).
"""
regularization_label(λ) =
    λ == 0 ? "λ = 0" : "λ = " * replace((@sprintf "%.0e" λ), "e-0" => "e-", "e+0" => "e")

"""
    RegularizationConfig(λ::Real)

A configuration holding the *same* factor `λ` at every precision, labelled by its
value. This is how the `λ = 0` control of the nonlinear sweep is built, and the
convenient form for a one-off investigation at a hand-picked value.
"""
RegularizationConfig(λ::Real) =
    RegularizationConfig(regularization_label(λ), nothing, T -> T(λ))

# The two regularization ladders, as exponents `k` of `2^k √eps(T)`. `Float64` needs
# its own because `√eps` spans four orders of magnitude across the benchmarked formats
# (`1.5e-8` against `8.8e-2` at `BFloat16`): multipliers that reach a useful shift in
# double precision over-damp half precision several times over. Both ladders contain
# `16√eps(T)`, NonlinearIntegrators' recommended default — rung 4 of the low-precision
# ladder, rung 2 of the `Float64` one — so each is anchored on a known-good shift and
# probes octaves either side of it.
const _REG_EXPONENTS_LOW = (1, 2, 3, 4, 5, 6)
const _REG_EXPONENTS_F64 = (2, 4, 6, 8, 10, 12)

"""
    regularization_exponent(T, rung)

The exponent `k` for which `rung` of the regularization ladder is `2^k √eps(T)`.
`Float64` uses `$(_REG_EXPONENTS_F64)`; every other precision uses
`$(_REG_EXPONENTS_LOW)`.
"""
regularization_exponent(::Type{Float64}, rung::Integer) = _REG_EXPONENTS_F64[rung]
regularization_exponent(::Type{T}, rung::Integer) where {T} = _REG_EXPONENTS_LOW[rung]

# `2^k √eps(T)`, formed in `Float64` and converted once. Computing it as
# `T(2)^k * sqrt(eps(T))` instead overflows to `Inf` for `Float16` from `k = 16` on,
# and `run_nonlinear_case` records every exception as a non-converged row, so that
# would turn a rung into a silent non-run. Taking `eps` to `Float64` first also keeps
# `sqrt` off the `BFloat16` path.
_regularization_factor(::Type{T}, rung::Integer) where {T} =
    T(2.0^regularization_exponent(T, rung) * sqrt(Float64(eps(T))))

"""
    scaled_regularization(rung)

Return the [`RegularizationConfig`](@ref) for `rung` of the precision-scaled ladder:
a factor of `2^k √eps(T)`, with `k = `[`regularization_exponent`](@ref)`(T, rung)`.
Labelled `"λ rung \$rung"` — by position rather than by value, so that the panel
label is the same across precisions even though the value is not.
"""
function scaled_regularization(rung::Integer)
    rung in eachindex(_REG_EXPONENTS_LOW) ||
        throw(ArgumentError("rung must be in $(eachindex(_REG_EXPONENTS_LOW)), got $rung"))
    RegularizationConfig("λ rung $rung", rung, T -> _regularization_factor(T, rung))
end

"""
    default_initial_guesses()

Return the default list of [`InitialGuessConfig`](@ref)s:
`HermiteExtrapolation` (the integrator default), `MidpointExtrapolation`, and
`NoInitialGuess` (which reuses the solution of the previous time step).
"""
default_initial_guesses() = [
    InitialGuessConfig("HermiteExtrapolation",  () -> HermiteExtrapolation()),
    InitialGuessConfig("MidpointExtrapolation", () -> MidpointExtrapolation()),
    InitialGuessConfig("NoInitialGuess",        () -> NoInitialGuess()),
]

"""
    default_precisions()

Return the default tuple of floating point precisions to benchmark:
`(BFloat16, Float16, Float32, Float64)`.

The two 16-bit formats are both swept because they trade the same 16 bits
differently: `Float16` spends 11 bits on the significand and 5 on the exponent,
`BFloat16` only 8 on the significand but 8 on the exponent — the same range as
`Float32`. Sweeping both separates a failure caused by too few digits from one
caused by too little dynamic range.
"""
default_precisions() = (BFloat16, Float16, Float32, Float64)
