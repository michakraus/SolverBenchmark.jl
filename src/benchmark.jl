# Solver options passed to the integrator, merged over `default_options(method,
# problem)` — so only what the harness changes is listed:
#  - `verbosity`/`warn_iterations`: the harness records (non-)convergence itself, so
#    the solver stays silent. Both are needed — the "Solver took N iterations"
#    warning is gated by `warn_iterations`, not `verbosity`, and would otherwise
#    fire on every step of a divergent run.
#  - `max_iterations`: converging configurations need only a handful of iterations,
#    so this modest cap merely bounds how long divergent ones run.
#  - `f_abstol`: absolute residual tolerance. The framework default,
#    `max(8, solversize(method, problem)) * eps(T)`, is `8 eps(T)` for every problem
#    benchmarked here; stated explicitly so it can be relaxed per problem
#    (see `ProblemSpec`).
function _solver_options(::Type{T}; max_iterations::Integer = 100,
        f_abstol::Real = 8 * eps(T)) where {T}
    (max_iterations = max_iterations, f_abstol = f_abstol,
        verbosity = 0, warn_iterations = 0)
end

# `_solver_options` silences everything the *benchmarked* solver emits. Two
# sources of chatter remain that no solver option can reach, which is what
# `quiet = true` suppresses:
#
#  1. `HermiteExtrapolation` warns whenever two consecutive history entries
#     coincide (a step whose solve does not move `q`). Emitted by
#     GeometricIntegratorsBase, whose `nowarn` keyword is not threaded through
#     `GeometricIntegrator`.
#  2. `NonLinear_OneLayer_GML` seeds each step with its own inner integrator —
#     `integrate(tem_ode, ImplicitMidpoint())`, called with *no* options, so that
#     solve runs at the SimpleSolvers defaults (`verbosity = 1`,
#     `warn_iterations = 1000`) behind a `Backtracking` line search regardless of
#     what the benchmarked solver is configured with. Its warnings carry
#     SimpleSolvers as their module, so filtering GeometricIntegratorsBase alone
#     does not catch them. Forwarding the outer options to that inner `integrate`
#     upstream would remove the need for `quiet` in the nonlinear sweep.
#
# Filtering just these two modules keeps documentation builds quiet without hiding
# warnings from anywhere else; the harness's own failed-run warning is gated
# separately on `quiet`.
struct _QuietLogger{L <: Logging.AbstractLogger} <: Logging.AbstractLogger
    parent::L
end

Logging.min_enabled_level(l::_QuietLogger) = Logging.min_enabled_level(l.parent)
Logging.catch_exceptions(l::_QuietLogger) = Logging.catch_exceptions(l.parent)
function Logging.shouldlog(l::_QuietLogger, level, _module, group, id)
    _module !== GIB && _module !== SimpleSolvers &&
        Logging.shouldlog(l.parent, level, _module, group, id)
end
function Logging.handle_message(l::_QuietLogger, args...; kwargs...)
    Logging.handle_message(l.parent, args...; kwargs...)
end

function _maybe_quiet(body, quiet::Bool)
    quiet ? Logging.with_logger(body, _QuietLogger(Logging.current_logger())) : body()
end

# Build a `GeometricIntegrator` for one solver/line-search/initial-guess combination.
# `DogLeg` and `Picard` do not accept a line search, so the keyword is omitted for them.
function _build_integrator(prob, method, scfg::SolverConfig, iguess, ::Type{T};
        max_iterations::Integer = 100,
        f_abstol::Real = 8 * eps(T)) where {T}
    opts = _solver_options(T; max_iterations, f_abstol)
    if scfg.linesearch === nothing
        GeometricIntegrator(
            prob, method; solver = scfg.solver, initialguess = iguess, opts...)
    else
        GeometricIntegrator(prob, method; solver = scfg.solver, initialguess = iguess,
            linesearch = scfg.linesearch(T), opts...)
    end
end

# Drive the integrator one step at a time so the nonlinear-solver statistics
# (iteration counts, residuals, convergence) can be read after every step.
# Returns the solution together with accumulated solver metrics.
function _drive!(int, prob)
    sol = GeometricSolution(prob)
    solstep = GIB.solutionstep(int, sol[0])
    curstate = GIB.current(solstep)
    cfg = SimpleSolvers.config(GIB.solver(int))

    total_iters = 0
    nsteps = 0
    max_residual = 0.0
    all_converged = true
    nan_step = 0                        # step at which NaNs first appeared (0 = none)

    N = ntime(sol)
    for n in 1:N
        reset!(solstep, timesteps(sol)[n])
        integrate!(solstep, int)
        copy!(sol, curstate, n)

        state = GIB.solverstate(int)
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
    run_case(spec, T, scfg, igcfg; method = ImplicitMidpoint(), timing = :quick,
             max_iterations = 100, quiet = false)

Run a single benchmark combination: integrate the problem described by `spec` at
precision `T` using solver configuration `scfg`, initial guess `igcfg`, and the
given integrator `method`. Returns a `NamedTuple` row of metrics.

`timing` selects how the run time is measured:
- `:none` — do not measure run time (`runtime_s` is `missing`); the trajectory is
  integrated only once, which is the fastest option (used by the test suite).
- `:quick` — a single `@elapsed` (fast; used for documentation builds).
- `:benchmark` — `BenchmarkTools.@belapsed` (accurate but slow; used by scripts).

`max_iterations` caps the nonlinear solver's iterations per step; converging
configurations use far fewer, so this mainly bounds how long divergent ones run.

With `quiet = true` the warning reporting a failed run is suppressed (useful in
documentation builds); the failure is recorded as a non-converged row regardless.

Any error during integration (e.g. a divergent solve in low precision) is caught
and recorded as a non-converged row rather than aborting the whole sweep.
"""
function run_case(
        spec::ProblemSpec, ::Type{T}, scfg::SolverConfig, igcfg::InitialGuessConfig;
        method = ImplicitMidpoint(), timing::Symbol = :quick,
        max_iterations::Integer = 100, quiet::Bool = false) where {T}

    # recorded alongside the residual so that `max_residual` can be read against the
    # target it was actually solved to — see `summary_table`
    f_abstol = spec.f_abstol_factor * eps(T)

    base = (problem = spec.name, precision = precision_label(T),
        solver = scfg.solver_name, linesearch = scfg.linesearch_name,
        solver_label = solver_label(scfg), initial_guess = igcfg.name,
        f_abstol = Float64(f_abstol))

    missing_row = (; base..., converged = false,
        iterations_total = missing, iterations_mean = missing,
        runtime_s = missing, max_residual = missing,
        energy_drift = missing, accuracy = missing)

    _maybe_quiet(quiet) do
        try
            prob = spec.builder(T)
            params = GIB.parameters(prob)
            int = _build_integrator(prob, method, scfg, igcfg.build(), T;
                max_iterations, f_abstol)

            # one representative run for the solver/accuracy metrics
            res = _drive!(int, prob)

            # timing (integrator is warm after the representative run). The
            # BenchmarkTools budget is capped so that non-converging configurations
            # (which spend far more iterations per step than converging ones) do not
            # dominate wall time. `:none` skips the extra timing run entirely.
            runtime = if timing === :benchmark
                @belapsed _drive!($int, $prob) samples=100 seconds=2
            elseif timing === :quick
                @elapsed _drive!(int, prob)
            else
                missing
            end

            # accuracy metrics (only meaningful for a converged, finite trajectory)
            energy_drift = missing
            accuracy = missing
            if res.converged
                sol = res.sol
                # HODE/IODE solutions carry a separate momentum `p`; ODE solutions do
                # not (their state is bundled into `q`), so pass `nothing` there.
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
                iterations_mean = res.nsteps == 0 ? missing : res.total_iters / res.nsteps,
                runtime_s = runtime === missing ? missing : Float64(runtime),
                max_residual = res.max_residual, energy_drift, accuracy)
        catch err
            quiet ||
                @warn "run_case failed" problem=spec.name precision=T solver=solver_label(scfg) initial_guess=igcfg.name exception=err
            return missing_row
        end
    end  # _maybe_quiet
end

"""
    run_benchmark(spec; method = ImplicitMidpoint(), precisions = default_precisions(),
                  solver_configs = default_solver_configs(),
                  initial_guesses = default_initial_guesses(),
                  timing = :quick, max_iterations = 100, verbose = true, quiet = false)

Run the full benchmark grid for one problem `spec` and return the results as a
`DataFrame`, one row per (precision × solver configuration × initial guess)
combination. See [`run_case`](@ref) for the meaning of `timing`, `max_iterations`
and `quiet`. Set `verbose = false` to suppress the per-combination progress log.
"""
function run_benchmark(spec::ProblemSpec;
        method = ImplicitMidpoint(),
        precisions = default_precisions(),
        solver_configs = default_solver_configs(),
        initial_guesses = default_initial_guesses(),
        timing::Symbol = :quick,
        max_iterations::Integer = 100,
        verbose::Bool = true,
        quiet::Bool = false)
    rows = Vector{Any}()
    for T in precisions, scfg in solver_configs, igcfg in initial_guesses
        verbose &&
            @info "benchmarking" problem=spec.name precision=T solver=solver_label(scfg) initial_guess=igcfg.name
        push!(rows, run_case(spec, T, scfg, igcfg; method, timing, max_iterations, quiet))
    end
    DataFrame(rows)
end
