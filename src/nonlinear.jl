# Second experiment set: the neural-network variational integrator
# `NonLinear_OneLayer_GML` from NonlinearIntegrators.jl. Unlike the implicit
# midpoint sweep (precision × solver × initial guess), this sweep varies the
# solver's `regularization_factor` in place of the initial guess (the network
# integrator uses its own built-in initial guess, `OGA1d`), across the same set
# of precisions and a reduced set of solver configurations.
#
# The network integrator solves a near-singular nonlinear system, so a nonzero
# `regularization_factor` (a Levenberg–Marquardt-style shift added to the Newton
# Jacobian diagonal) is essential for convergence — which is exactly what this
# experiment set is designed to expose.

# Number of dictionary neurons for the OGA initial guess. A few hundred is as
# accurate as the reference's 400000 on the harmonic oscillator (and much faster);
# the dictionary is built in double precision (see NonlinearIntegrators), so this
# is independent of the working precision.
const NONLINEAR_DICT_AMOUNT = 400

"""
    harmonic_oscillator_lode_spec(; timespan = (0.0, 1.0), timestep = 0.1)

Return a [`ProblemSpec`](@ref) for the harmonic oscillator built as an
**`lodeproblem`** (Lagrangian form), as required by the `NonLinear_OneLayer_GML`
integrator. The analytic solution is provided (via
`HarmonicOscillator.exact_solution_q`), so accuracy is measured directly.

The nonlinear network solve has a residual floor well above `8 eps(T)`, so the
solver tolerance is relaxed to `256 eps(T)` (`f_abstol_factor = 256`); with the
default `8 eps(T)` even a well-solved step is reported as non-converged at
`Float32`.
"""
function harmonic_oscillator_lode_spec(; q₀ = [0.5], p₀ = [0.0], timespan = (0.0, 1.0), timestep = 0.1)
    builder = T -> HarmonicOscillator.lodeproblem(T.(q₀), T.(p₀), T;
        timespan = (T(timespan[1]), T(timespan[2])), timestep = T(timestep),
        parameters = HarmonicOscillator.default_parameters(T))

    energy = (t, q, p, params) -> HarmonicOscillator.hamiltonian(t, q, p, params)

    # The LODE state carries positions only, so the analytic solution is
    # reconstructed from the (fixed) initial momentum captured here rather than
    # from `sol.q[0]` alone.
    t₀ = timespan[1]
    p̄₀ = p₀[1]
    reference = (t, x₀, params) -> [HarmonicOscillator.exact_solution_q(t, x₀[1], p̄₀, t₀, params)]

    ProblemSpec("HarmonicOscillatorLODE", builder, energy, reference; f_abstol_factor = 256)
end

"""
    nonlinear_onelayer_method(T; R = 8, S = 4, k = 3, bias_interval = [-π, π],
                              dict_amount = NONLINEAR_DICT_AMOUNT)

Construct a `NonLinear_OneLayer_GML` integrator at precision `T`: a one-layer
network with `S` neurons and activation `x -> max(0, x)^k`, integrated with an
`R`-point Gauss–Legendre quadrature. The network basis and the quadrature are
both built at `T` (the constructor requires them to share the element type), so
the integration runs genuinely at the requested precision.
"""
function nonlinear_onelayer_method(::Type{T}; R = 8, S = 4, k = 3,
                                   bias_interval = [-π, π],
                                   dict_amount = NONLINEAR_DICT_AMOUNT) where {T}
    activation = x -> max(zero(x), x)^k
    network    = OneLayerNetwork_GML{T}(activation, S)
    quadrature = GaussLegendreQuadrature(T, R)
    NonLinear_OneLayer_GML(network, quadrature;
        bias_interval = T.(bias_interval), dict_amount = dict_amount)
end

"""
    nonlinear_solver_configs()

Return the reduced list of [`SolverConfig`](@ref)s benchmarked for the nonlinear
integrator: `Newton` with the `Static`, `Backtracking` and `StrongWolfe` line
searches, plus `DogLeg` (which takes no line search) — four configurations.
"""
nonlinear_solver_configs() = [
    SolverConfig("Newton", "Static",       Newton(), T -> Static(T)),
    SolverConfig("Newton", "Backtracking", Newton(), T -> Backtracking(T)),
    SolverConfig("Newton", "StrongWolfe",  Newton(), T -> StrongWolfe(T)),
    SolverConfig("DogLeg", "",             DogLeg(), nothing),
]

"""
    nonlinear_regularization_factors()

Return the list of solver `regularization_factor` values swept for the nonlinear
integrator: `[0.0, 1e-3, 1e-5, 1e-7]`.
"""
nonlinear_regularization_factors() = [0.0, 1e-3, 1e-5, 1e-7]

# Compact panel label for a regularization factor, e.g. "λ = 0", "λ = 1e-3".
# The benchmark sweeps λ in the innermost loop, so the labels appear in the
# DataFrame in this order and the plots/table pick that order up automatically.
regularization_label(λ) =
    λ == 0 ? "λ = 0" : "λ = " * replace((@sprintf "%.0e" λ), "e-0" => "e-", "e+0" => "e")

"""
    run_nonlinear_case(spec, T, scfg, λ, method; timing = :quick,
                       max_iterations = 1000, quiet = false)

Run a single nonlinear-integrator benchmark combination: integrate the LODE
`spec` at precision `T` with solver configuration `scfg`, regularization factor
`λ`, and the prebuilt integrator `method`. Uses the integrator's own initial
guess (no `initialguess` is passed). Returns a `NamedTuple` row of metrics with a
`regularization` panel label; see [`run_case`](@ref) for the `timing` semantics.
"""
function run_nonlinear_case(spec::ProblemSpec, ::Type{T}, scfg::SolverConfig, λ::Real, method;
                            timing::Symbol = :quick, max_iterations::Integer = 1000,
                            quiet::Bool = false) where {T}

    base = (problem = spec.name, precision = string(T),
            solver = scfg.solver_name, linesearch = scfg.linesearch_name,
            solver_label = solver_label(scfg), regularization = regularization_label(λ))

    missing_row = (; base..., converged = false,
                   iterations_total = missing, iterations_mean = missing,
                   runtime_s = missing, max_residual = missing,
                   energy_drift = missing, accuracy = missing)

    body = function ()
    try
        prob   = spec.builder(T)
        params = GIB.parameters(prob)

        opts = merge(_solver_options(T; max_iterations, f_abstol = spec.f_abstol_factor * eps(T)),
                     (; regularization_factor = T(λ)))
        int  = if scfg.linesearch === nothing
            GeometricIntegrator(prob, method; solver = scfg.solver, opts...)
        else
            GeometricIntegrator(prob, method; solver = scfg.solver,
                linesearch = scfg.linesearch(T), opts...)
        end

        res = _drive!(int, prob)

        runtime = if timing === :benchmark
            @belapsed _drive!($int, $prob) samples = 100 seconds = 2
        elseif timing === :quick
            @elapsed _drive!(int, prob)
        else
            missing
        end

        energy_drift = missing
        accuracy     = missing
        if res.converged
            sol = res.sol
            hasp = hasproperty(sol, :p)
            t₀, q₀ = sol.t[0], sol.q[0]
            t₁, q₁ = sol.t[res.last_good], sol.q[res.last_good]
            p₀ = hasp ? sol.p[0] : nothing
            p₁ = hasp ? sol.p[res.last_good] : nothing
            H₀ = spec.energy(t₀, q₀, p₀, params)
            H₁ = spec.energy(t₁, q₁, p₁, params)
            energy_drift = Float64(abs(H₁ - H₀))
            if spec.reference !== nothing
                accuracy = Float64(maximum(abs, q₁ .- spec.reference(t₁, q₀, params)))
            end
        end

        return (; base..., converged = res.converged,
                iterations_total = res.total_iters,
                iterations_mean  = res.nsteps == 0 ? missing : res.total_iters / res.nsteps,
                runtime_s = runtime === missing ? missing : Float64(runtime),
                max_residual = res.max_residual, energy_drift, accuracy)
    catch err
        @warn "run_nonlinear_case failed" problem = spec.name precision = T solver = solver_label(scfg) regularization = λ exception = err
        return missing_row
    end
    end  # body

    return quiet ? Logging.with_logger(body, Logging.NullLogger()) : body()
end

"""
    run_nonlinear_benchmark(spec; method_builder = nonlinear_onelayer_method,
                            precisions = default_precisions(),
                            solver_configs = nonlinear_solver_configs(),
                            regularization_factors = nonlinear_regularization_factors(),
                            timing = :quick, max_iterations = 1000,
                            verbose = true, quiet = false)

Run the full nonlinear-integrator benchmark grid for one LODE `spec` and return
the results as a `DataFrame`, one row per (precision × solver configuration ×
regularization factor). The integrator `method` is built once per precision via
`method_builder(T)` and reused across the solver/regularization sweep (building
the network is relatively expensive).
"""
function run_nonlinear_benchmark(spec::ProblemSpec;
                                 method_builder = nonlinear_onelayer_method,
                                 precisions = default_precisions(),
                                 solver_configs = nonlinear_solver_configs(),
                                 regularization_factors = nonlinear_regularization_factors(),
                                 timing::Symbol = :quick,
                                 max_iterations::Integer = 1000,
                                 verbose::Bool = true,
                                 quiet::Bool = false)

    rows = Vector{Any}()
    for T in precisions
        method = method_builder(T)
        for scfg in solver_configs, λ in regularization_factors
            verbose && @info "benchmarking" problem = spec.name precision = T solver = solver_label(scfg) regularization = λ
            push!(rows, run_nonlinear_case(spec, T, scfg, λ, method; timing, max_iterations, quiet))
        end
    end
    DataFrame(rows)
end
