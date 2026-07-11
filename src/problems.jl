"""
    ProblemSpec

Specification of an example problem to be benchmarked. It bundles everything the
benchmark harness needs to build and assess a problem at an arbitrary floating
point precision `T`, keeping the harness itself independent of any particular
problem from `GeometricProblems.jl`.

# Fields
- `name::String`: human readable problem name (used for labelling and file names).
- `builder`: callable `T -> problem` returning an `ODEProblem` at precision `T`.
- `energy`: callable `(t, q, p, params) -> H` computing the conserved energy /
  invariant from the positions `q` and momenta `p`. Used as an accuracy proxy
  (energy drift). `p` is `nothing` for problems whose solution carries no separate
  momentum (an `ODEProblem` state already bundles both into `q`); Hamiltonians
  that depend on positions alone simply ignore the argument.
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

    energy = (t, q, p, params) -> HarmonicOscillator.hamiltonian(t, q, params)

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

    energy = (t, q, p, params) -> Pendulum.hamiltonian(t, q, params)

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

    energy = (t, q, p, params) -> LotkaVolterra2d.hamiltonian(t, q, params)

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

    energy = (t, q, p, params) -> LotkaVolterra4d.hamiltonian(t, q, params)

    ProblemSpec("LotkaVolterra4d", builder, energy, nothing)
end

"""
    double_pendulum_spec(; q₀ = DoublePendulum.θ₀, p₀ = DoublePendulum.p₀,
                           timespan = (0.0, 10.0), timestep = 0.01)

Return a [`ProblemSpec`](@ref) for the double pendulum from
`GeometricProblems.DoublePendulum`, built as an **`hodeproblem`** (canonical
Hamiltonian form). This is a chaotic, strongly nonlinear system, so it exercises
the nonlinear solvers hard. Its Hamiltonian `H(t, q, p)` depends on **both** the
generalized coordinates `q` and the momenta `p`, so the energy proxy is evaluated
from the full `(q, p)` state. No closed-form solution exists; accuracy is
assessed through the energy drift.

The default initial conditions and parameters are the problem's own module
defaults; the native time span is `(0, 10)` with the standard `Δt = 0.01`
(a coarse `Δt = 0.1` is used as a second scenario).
"""
function double_pendulum_spec(; q₀ = DoublePendulum.θ₀, p₀ = DoublePendulum.p₀,
                                timespan = (0.0, 10.0), timestep = 0.01)
    builder = T -> DoublePendulum.hodeproblem(T.(q₀), T.(p₀);
        timespan = (T(timespan[1]), T(timespan[2])), timestep = T(timestep),
        parameters = _typed_parameters(T, DoublePendulum.default_parameters))

    energy = (t, q, p, params) -> DoublePendulum.hamiltonian(t, q, p, params)

    ProblemSpec("DoublePendulum", builder, energy, nothing)
end

"""
    toda_lattice_spec(; N = 16, μ = 0.3, timespan = (0.0, 100.0), timestep = 0.1)

Return a [`ProblemSpec`](@ref) for the Toda lattice from
`GeometricProblems.TodaLattice`, built as an **`hodeproblem`** with `N = 16`
lattice sites. The full soliton example uses `N = 200`, which would make the
implicit solves prohibitively expensive for a solver benchmark, so a modest
`N = 16` is used here. The lattice size is passed positionally to `hodeproblem`;
the initial positions come from `compute_initial_q(μ, N)` (a bump of width `μ`)
with zero initial momenta. Its Hamiltonian `H(t, q, p, N)` depends on both `q`
and `p` (and on `N`, which the energy closure captures). No closed-form solution
exists; accuracy is assessed through the energy drift.

The native time span `(0, 120)` is shortened to `(0, 100)` with the standard
`Δt = 0.1`; a coarse `Δt = 1.0` is used as a second scenario.
"""
function toda_lattice_spec(; N = 16, μ = 0.3, timespan = (0.0, 100.0), timestep = 0.1)
    builder = function (T)
        q₀ = T.(TodaLattice.compute_initial_q(μ, N))
        p₀ = zero(q₀)
        TodaLattice.hodeproblem(N, q₀, p₀;
            timespan = (T(timespan[1]), T(timespan[2])), timestep = T(timestep),
            parameters = _typed_parameters(T, TodaLattice.default_parameters))
    end

    energy = (t, q, p, params) -> TodaLattice.hamiltonian(t, q, p, params, N)

    ProblemSpec("TodaLattice", builder, energy, nothing)
end
