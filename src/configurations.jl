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
