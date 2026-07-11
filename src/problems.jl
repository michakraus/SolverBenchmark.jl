"""
    ProblemSpec

Specification of an example problem to be benchmarked. It bundles everything the
benchmark harness needs to build and assess a problem at an arbitrary floating
point precision `T`, keeping the harness itself independent of any particular
problem from `GeometricProblems.jl`.

# Fields
- `name::String`: human readable problem name (used for labelling and file names).
- `builder`: callable `T -> problem` returning an `ODEProblem` at precision `T`.
- `energy`: callable `(t, x, params) -> H` computing the conserved energy /
  invariant from a state vector `x`. Used as an accuracy proxy (energy drift).
- `reference`: callable `(t, x₀, params) -> x` giving the analytic solution at
  time `t`, or `nothing` when no closed-form solution is available.
"""
struct ProblemSpec
    name::String
    builder::Function
    energy::Function
    reference::Union{Function,Nothing}
end

ProblemSpec(name, builder, energy) = ProblemSpec(name, builder, energy, nothing)

"""
    harmonic_oscillator_spec(; x₀ = [0.5, 0.0], timespan = (0.0, 100.0), timestep = 0.1)

Return a [`ProblemSpec`](@ref) for the harmonic oscillator from
`GeometricProblems.HarmonicOscillator`, integrated as an `ODEProblem`
(`ẋ₁ = x₂`, `ẋ₂ = -k x₁`). The analytic solution is provided, so the accuracy
of every run can be measured directly.
"""
function harmonic_oscillator_spec(; x₀ = [0.5, 0.0], timespan = (0.0, 100.0), timestep = 0.1)
    builder = T -> HarmonicOscillator.odeproblem(T.(x₀);
        timespan = (T(timespan[1]), T(timespan[2])), timestep = T(timestep))

    energy = (t, x, params) -> HarmonicOscillator.hamiltonian(t, x, params)

    reference = function (t, x₀, params)
        ω = sqrt(params.k)            # dynamical frequency of ẍ = -k x
        q₀, v₀ = x₀[1], x₀[2]
        q = q₀ * cos(ω * t) + (v₀ / ω) * sin(ω * t)
        v = v₀ * cos(ω * t) - (q₀ * ω) * sin(ω * t)
        [q, v]
    end

    ProblemSpec("HarmonicOscillator", builder, energy, reference)
end

"""
    pendulum_spec(; x₀ = [acos(0.4), 0.0], timespan = (0.0, 100.0), timestep = 0.1)

Return a [`ProblemSpec`](@ref) for the mathematical pendulum from
`GeometricProblems.Pendulum`, integrated as an `ODEProblem`. The pendulum is
nonlinear, so it exercises the nonlinear solvers more than the (linear)
harmonic oscillator. No closed-form solution is used; accuracy is assessed
through the energy drift of the Hamiltonian `H = p²/(2ml²) + m g l cos(q)`.
"""
function pendulum_spec(; x₀ = [acos(0.4), 0.0], timespan = (0.0, 100.0), timestep = 0.1)
    builder = T -> Pendulum.odeproblem(T.(x₀);
        timespan = (T(timespan[1]), T(timespan[2])), timestep = T(timestep))

    energy = (t, x, params) -> Pendulum.hamiltonian(t, x, params)

    ProblemSpec("Pendulum", builder, energy, nothing)
end

# Convert a parameter NamedTuple to element type `T` so the whole problem
# (state and parameters) is integrated consistently at the requested precision.
_typed_parameters(::Type{T}, nt::NamedTuple) where {T} = NamedTuple{keys(nt)}(map(T, values(nt)))

"""
    lotka_volterra_2d_spec(; q₀ = [2.0, 1.0], timespan = (0.0, 10.0), timestep = 0.01)

Return a [`ProblemSpec`](@ref) for the 2d Lotka–Volterra system from
`GeometricProblems.LotkaVolterra2d`, built as an **`iodeproblem`** (implicit
ODE / degenerate Lagrangian form). This is a nonlinear, non-canonical Hamiltonian
system; its Hamiltonian `H = a₁q₁ + a₂q₂ + b₁\\log q₁ + b₂\\log q₂` depends on the
positions `q` alone, and is used for the energy-drift accuracy metric.

The default time span/step are the problem's native `(0, 10)` with `Δt = 0.01`
(1000 steps): the coarse `Δt = 0.1` used for the oscillator/pendulum is too large
for this stiffer system.
"""
function lotka_volterra_2d_spec(; q₀ = [2.0, 1.0], timespan = (0.0, 10.0), timestep = 0.01)
    builder = T -> LotkaVolterra2d.iodeproblem(T.(q₀);
        timespan = (T(timespan[1]), T(timespan[2])), timestep = T(timestep),
        parameters = _typed_parameters(T, LotkaVolterra2d.default_parameters))

    energy = (t, x, params) -> LotkaVolterra2d.hamiltonian(t, x, params)

    ProblemSpec("LotkaVolterra2d", builder, energy, nothing)
end

"""
    lotka_volterra_4d_spec(; q₀ = [2.0, 1.0, 1.0, 1.0], timespan = (0.0, 10.0), timestep = 0.01)

Return a [`ProblemSpec`](@ref) for the 4d Lotka–Volterra system from
`GeometricProblems.LotkaVolterra4d`, built as an **`iodeproblem`**. Like the 2d
case it is a non-canonical Hamiltonian system with
`H = a·q + b·\\log q` (positions only), used for the energy-drift metric. It is
more strongly degenerate than the 2d system and is a demanding test for the
nonlinear solvers — low precision typically fails with a singular Jacobian.

Uses the native `(0, 10)` time span with `Δt = 0.01`.
"""
function lotka_volterra_4d_spec(; q₀ = [2.0, 1.0, 1.0, 1.0], timespan = (0.0, 10.0), timestep = 0.01)
    builder = T -> LotkaVolterra4d.iodeproblem(T.(q₀);
        timespan = (T(timespan[1]), T(timespan[2])), timestep = T(timestep),
        parameters = _typed_parameters(T, LotkaVolterra4d.default_parameters))

    energy = (t, x, params) -> LotkaVolterra4d.hamiltonian(t, x, params)

    ProblemSpec("LotkaVolterra4d", builder, energy, nothing)
end
