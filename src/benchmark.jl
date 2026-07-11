# Solver-option keyword arguments passed to the integrator. Passing any options
# replaces the integrator defaults entirely, so we restate the defaults
# (`min_iterations = 1`, `f_abstol = 8 eps(T)`) alongside a generous iteration cap.
# The harness detects (non-)convergence itself and records it per run, so the
# solver's own chatter is turned off: `verbosity = 0` and `warn_iterations = 0`
# (the "Solver took N iterations" warning is gated by `warn_iterations`, not
# `verbosity`, and would otherwise fire on every step of a divergent run).
_solver_options(::Type{T}) where {T} =
    (min_iterations = 1, max_iterations = 1000, f_abstol = 8 * eps(T),
     verbosity = 0, warn_iterations = 0)

# Build a `GeometricIntegrator` for one solver/line-search/initial-guess combination.
# `DogLeg` and `Picard` do not accept a line search, so the keyword is omitted for them.
function _build_integrator(prob, method, scfg::SolverConfig, iguess, ::Type{T}) where {T}
    opts = _solver_options(T)
    if scfg.linesearch === nothing
        GeometricIntegrator(prob, method; solver = scfg.solver, initialguess = iguess, opts...)
    else
        GeometricIntegrator(prob, method; solver = scfg.solver, initialguess = iguess,
            linesearch = scfg.linesearch(T), opts...)
    end
end

# Drive the integrator one step at a time so the nonlinear-solver statistics
# (iteration counts, residuals, convergence) can be read after every step.
# Returns the solution together with accumulated solver metrics.
function _drive!(int, prob)
    sol      = GeometricSolution(prob)
    solstep  = GIB.solutionstep(int, sol[0])
    curstate = GIB.current(solstep)
    cfg      = SimpleSolvers.config(GIB.solver(int))

    total_iters   = 0
    nsteps        = 0
    max_residual  = 0.0
    all_converged = true
    nan_step      = 0                        # step at which NaNs first appeared (0 = none)

    N = ntime(sol)
    for n in 1:N
        integrate!(solstep, int)
        copy!(sol, curstate, n)

        state  = GIB.solverstate(int)
        total_iters += SimpleSolvers.iteration_number(state)
        status = SimpleSolvers.NonlinearSolverStatus(state, cfg)
        all_converged &= SimpleSolvers.isconverged(status)
        max_residual = max(max_residual, Float64(status.rfₐ))
        nsteps += 1

        if any(isnan, GIB.current(solstep).q)
            nan_step = n
            break
        end
    end

    last_good = nan_step == 0 ? N : nan_step - 1
    converged = all_converged && nan_step == 0

    return (; sol, total_iters, nsteps, max_residual, converged, last_good)
end

"""
    run_case(spec, T, scfg, igcfg; method = ImplicitMidpoint(), timing = :quick, quiet = false)

Run a single benchmark combination: integrate the problem described by `spec` at
precision `T` using solver configuration `scfg`, initial guess `igcfg`, and the
given integrator `method`. Returns a `NamedTuple` row of metrics.

`timing` selects how the run time is measured:
- `:quick` — a single `@elapsed` (fast; used for documentation builds).
- `:benchmark` — `BenchmarkTools.@belapsed` (accurate but slow; used by scripts).

With `quiet = true` any warnings emitted while integrating are suppressed (useful
in documentation builds); convergence is recorded regardless.

Any error during integration (e.g. a divergent solve in low precision) is caught
and recorded as a non-converged row rather than aborting the whole sweep.
"""
function run_case(spec::ProblemSpec, ::Type{T}, scfg::SolverConfig, igcfg::InitialGuessConfig;
                  method = ImplicitMidpoint(), timing::Symbol = :quick,
                  quiet::Bool = false) where {T}

    base = (problem = spec.name, precision = string(T),
            solver = scfg.solver_name, linesearch = scfg.linesearch_name,
            solver_label = solver_label(scfg), initial_guess = igcfg.name)

    missing_row = (; base..., converged = false,
                   iterations_total = missing, iterations_mean = missing,
                   runtime_s = missing, max_residual = missing,
                   energy_drift = missing, accuracy = missing)

    body = function ()
    try
        prob   = spec.builder(T)
        params = GIB.parameters(prob)
        int    = _build_integrator(prob, method, scfg, igcfg.build(), T)

        # one representative run for the solver/accuracy metrics
        res = _drive!(int, prob)

        # timing (integrator is warm after the representative run). The
        # BenchmarkTools budget is capped so that non-converging configurations
        # (which run to the iteration limit every step) do not dominate wall time.
        runtime = if timing === :benchmark
            @belapsed _drive!($int, $prob) samples = 100 seconds = 2
        else
            @elapsed _drive!(int, prob)
        end

        # accuracy metrics (only meaningful for a converged, finite trajectory)
        energy_drift = missing
        accuracy     = missing
        if res.converged
            sol = res.sol
            t₀, x₀ = sol.t[0], sol.q[0]
            t₁, x₁ = sol.t[res.last_good], sol.q[res.last_good]
            H₀ = spec.energy(t₀, x₀, params)
            H₁ = spec.energy(t₁, x₁, params)
            energy_drift = Float64(abs(H₁ - H₀))
            if spec.reference !== nothing
                accuracy = Float64(maximum(abs, x₁ .- spec.reference(t₁, x₀, params)))
            end
        end

        return (; base..., converged = res.converged,
                iterations_total = res.total_iters,
                iterations_mean  = res.nsteps == 0 ? missing : res.total_iters / res.nsteps,
                runtime_s = Float64(runtime), max_residual = res.max_residual,
                energy_drift, accuracy)
    catch err
        @warn "run_case failed" problem = spec.name precision = T solver = solver_label(scfg) initial_guess = igcfg.name exception = err
        return missing_row
    end
    end  # body

    return quiet ? Logging.with_logger(body, Logging.NullLogger()) : body()
end

"""
    run_benchmark(spec; method = ImplicitMidpoint(), precisions = default_precisions(),
                  solver_configs = default_solver_configs(),
                  initial_guesses = default_initial_guesses(),
                  timing = :quick, verbose = true, quiet = false)

Run the full benchmark grid for one problem `spec` and return the results as a
`DataFrame`, one row per (precision × solver configuration × initial guess)
combination. See [`run_case`](@ref) for the meaning of `timing` and `quiet`.
Set `verbose = false` to suppress the per-combination progress log.
"""
function run_benchmark(spec::ProblemSpec;
                       method = ImplicitMidpoint(),
                       precisions = default_precisions(),
                       solver_configs = default_solver_configs(),
                       initial_guesses = default_initial_guesses(),
                       timing::Symbol = :quick,
                       verbose::Bool = true,
                       quiet::Bool = false)

    rows = Vector{Any}()
    for T in precisions, scfg in solver_configs, igcfg in initial_guesses
        verbose && @info "benchmarking" problem = spec.name precision = T solver = solver_label(scfg) initial_guess = igcfg.name
        push!(rows, run_case(spec, T, scfg, igcfg; method, timing, quiet))
    end
    DataFrame(rows)
end
