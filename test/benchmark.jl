using SolverBenchmark
using DataFrames
using Test

# The tests use `timing = :none` (no extra timing integration) and, where a whole
# grid is swept, restrict to `Float64`, so this file exercises `run_case` and
# `run_benchmark` without the cost of the full precision × solver × guess matrix
# (that breadth is covered by the documentation and driver scripts).

@testset "run_case — harmonic oscillator (Float64)" begin
    spec = harmonic_oscillator_spec(timespan = (0.0, 1.0))
    scfg = first(default_solver_configs())        # Newton/Static
    igcfg = first(default_initial_guesses())       # HermiteExtrapolation

    # :quick measures the run time
    row = run_case(spec, Float64, scfg, igcfg; timing = :quick)
    @test row.problem == "HarmonicOscillator"
    @test row.precision == "Float64"
    @test row.converged
    @test row.iterations_total ≥ 1
    @test row.iterations_mean ≥ 1
    @test row.runtime_s > 0
    @test row.energy_drift < 1e-10                 # symplectic + linear ⇒ machine precision
    @test row.accuracy !== missing                 # analytic reference available

    # :none skips the timing run
    row_none = run_case(spec, Float64, scfg, igcfg; timing = :none)
    @test row_none.runtime_s === missing
    @test row_none.converged
end

@testset "precision coverage (harmonic oscillator)" begin
    spec = harmonic_oscillator_spec(timespan = (0.0, 1.0))
    scfg = default_solver_configs()[2]          # Newton/Backtracking
    hermite = first(default_initial_guesses())
    for T in (BFloat16, Float16, Float32)
        row = run_case(spec, T, scfg, hermite; timing = :none, quiet = true)
        # `nameof`, not `string`: the label has to be unqualified wherever it
        # is produced, because the plotting code matches it against
        # `_PRECISION_ORDER` and silently drops rows that do not match.
        @test row.precision == string(nameof(T))
        @test row.converged                        # linear problem converges at every precision
    end
    @test precision_label(BFloat16) == "BFloat16"
end

@testset "run_benchmark — full grid for one precision/guess" begin
    spec = harmonic_oscillator_spec(timespan = (0.0, 1.0))
    df = run_benchmark(spec; precisions = (Float64,),
        initial_guesses = default_initial_guesses()[1:1],
        timing = :none, verbose = false)
    @test nrow(df) == 8                            # 8 solver configs
    @test all(in(names(df)),
        ["converged", "iterations_mean", "runtime_s",
            "energy_drift", "accuracy", "solver_label"])
    @test count(df.converged) ≥ 6                  # at least the well-behaved solvers

    st = summary_table(df)
    @test nrow(st) == 8

    # `Bisection` stops as soon as `f_abstol` is met while the other line
    # searches overshoot it by two to three orders of magnitude, so on this
    # problem the flag picks out exactly the solvers that stop at the target.
    @test "at_tolerance" in names(st)
    @test st.at_tolerance[st.solver_label .== "Newton/Bisection"] == [true]
    @test st.at_tolerance[st.solver_label .== "Newton/Backtracking"] == [false]
end

@testset "at_tolerance flags a residual sitting at the target" begin
    # This problem's residual floor sits just under its target, not comfortably
    # below it: at these initial conditions the residual is ≈250 eps(T) against a
    # target of 256 eps(T), a margin of 2.4%. Whether a run converges is therefore
    # decided by the last bits of the arithmetic — `converged` is an AND over all
    # 100 steps, so one step landing a few percent over sinks it. Perturbing one
    # initial coordinate by a single ulp moves the residual anywhere in
    # 0.78…1.51× the target, and the runs above 1 do not converge.
    # `Newton/Static` is the configuration that flips, having no line search to
    # pull that step back; `Newton/Backtracking` does and stays converged.
    #
    # So assert what the flag is actually for — a converged run on this problem
    # stops *at* the target rather than below it — over the runs that did
    # converge. Those sit ≈9.8× above `f_abstol / 10` at these conditions, which
    # is real margin, where a blanket `all(st.at_tolerance)` is pinned to the 2.4%
    # boundary and reports the platform's rounding rather than the solver's
    # behaviour.
    spec = double_pendulum_spec(timespan = (0.0, 1.0), timestep = 0.01)
    df = run_benchmark(spec; precisions = (Float64,),
        solver_configs = default_solver_configs()[1:2],
        initial_guesses = default_initial_guesses()[1:1],
        timing = :none, verbose = false, quiet = true)
    @test "f_abstol" in names(df)
    @test all(df.f_abstol .== 256 * eps(Float64))

    st = summary_table(df)
    # the column survives `drop_empty` only when at least one row is flagged,
    # so this also asserts that some run landed at the target
    @test "at_tolerance" in names(st)
    @test all(st.at_tolerance[st.converged])

    # a run is flagged only when it converged *and* landed within a factor of
    # ten of its tolerance
    loose = copy(df)
    loose.max_residual .= df.f_abstol ./ 1000
    @test "at_tolerance" ∉ names(summary_table(loose))
end

@testset "run_case — pendulum has no analytic reference" begin
    spec = pendulum_spec(timespan = (0.0, 1.0))
    row = run_case(spec, Float64, first(default_solver_configs()),
        first(default_initial_guesses()); timing = :none)
    @test row.problem == "Pendulum"
    @test row.converged
    @test row.accuracy === missing
end

@testset "coarse time step (Δt = 1.0)" begin
    robust = default_solver_configs()[2]         # Newton/Backtracking
    hermite = first(default_initial_guesses())    # HermiteExtrapolation

    @testset "$name at Δt = 1.0" for (name, mk) in ((
        "HarmonicOscillator", harmonic_oscillator_spec),
        ("Pendulum", pendulum_spec))
        spec = mk(timespan = (0.0, 20.0), timestep = 1.0)
        row = run_case(spec, Float64, robust, hermite; timing = :none, quiet = true)
        @test row.problem == name
        @test row.converged
        @test row.iterations_mean ≥ 1
    end

    @testset "pendulum needs more Newton iterations at Δt = 1.0 than at Δt = 0.1" begin
        fine = run_case(pendulum_spec(timespan = (0.0, 20.0), timestep = 0.1),
            Float64, robust, hermite; timing = :none, quiet = true)
        coarse = run_case(pendulum_spec(timespan = (0.0, 20.0), timestep = 1.0),
            Float64, robust, hermite; timing = :none, quiet = true)
        @test fine.converged && coarse.converged
        @test coarse.iterations_mean > fine.iterations_mean
    end

    @testset "grid runs for both examples at Δt = 1.0 (Float64)" begin
        for mk in (harmonic_oscillator_spec, pendulum_spec)
            spec = mk(timespan = (0.0, 10.0), timestep = 1.0)
            df = run_benchmark(spec; precisions = (Float64,),
                timing = :none, verbose = false, quiet = true)
            @test nrow(df) == 24                  # 8 solver configs × 3 initial guesses
            @test count(df.converged) ≥ 6
        end
    end
end
