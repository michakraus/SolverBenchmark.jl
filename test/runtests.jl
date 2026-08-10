using SolverBenchmark
using DataFrames
using Test

# The tests use `timing = :none` (no extra timing integration) and, where a whole
# grid is swept, restrict to `Float64`, so the suite exercises every code path
# without the cost of the full precision × solver × guess matrix (that breadth is
# covered by the documentation and driver scripts).

@testset "SolverBenchmark.jl" begin

    @testset "configurations" begin
        cfgs = default_solver_configs()
        @test length(cfgs) == 8
        @test count(c -> c.solver_name == "Newton", cfgs) == 6
        @test count(c -> c.linesearch === nothing, cfgs) == 2   # DogLeg, Picard
        @test solver_label(cfgs[1]) == "Newton/Static"
        @test default_precisions() == (BFloat16, Float16, Float32, Float64)
        @test length(default_initial_guesses()) == 3
    end

    @testset "run_case — harmonic oscillator (Float64)" begin
        spec  = harmonic_oscillator_spec(timespan = (0.0, 1.0))
        scfg  = first(default_solver_configs())        # Newton/Static
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
        spec    = harmonic_oscillator_spec(timespan = (0.0, 1.0))
        scfg    = default_solver_configs()[2]          # Newton/Backtracking
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
        @test all(in(names(df)), ["converged", "iterations_mean", "runtime_s",
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
        # The double pendulum's residual floor is ≈200 eps(T) at every precision,
        # so with `f_abstol_factor = 256` every converged run stops *at* the
        # target rather than below it — which is exactly what the flag is for.
        spec = double_pendulum_spec(timespan = (0.0, 1.0), timestep = 0.01)
        df = run_benchmark(spec; precisions = (Float64,),
                           solver_configs = default_solver_configs()[1:2],
                           initial_guesses = default_initial_guesses()[1:1],
                           timing = :none, verbose = false, quiet = true)
        @test "f_abstol" in names(df)
        @test all(df.f_abstol .== 256 * eps(Float64))

        st = summary_table(df)
        @test "at_tolerance" in names(st)
        @test all(st.at_tolerance)

        # a run is flagged only when it converged *and* landed within a factor of
        # ten of its tolerance
        loose = copy(df)
        loose.max_residual .= df.f_abstol ./ 1000
        @test "at_tolerance" ∉ names(summary_table(loose))
    end

    @testset "run_case — pendulum has no analytic reference" begin
        spec  = pendulum_spec(timespan = (0.0, 1.0))
        row   = run_case(spec, Float64, first(default_solver_configs()),
                         first(default_initial_guesses()); timing = :none)
        @test row.problem == "Pendulum"
        @test row.converged
        @test row.accuracy === missing
    end

    @testset "coarse time step (Δt = 1.0)" begin
        robust  = default_solver_configs()[2]         # Newton/Backtracking
        hermite = first(default_initial_guesses())    # HermiteExtrapolation

        @testset "$name at Δt = 1.0" for (name, mk) in
                (("HarmonicOscillator", harmonic_oscillator_spec),
                 ("Pendulum", pendulum_spec))
            spec = mk(timespan = (0.0, 20.0), timestep = 1.0)
            row  = run_case(spec, Float64, robust, hermite; timing = :none, quiet = true)
            @test row.problem == name
            @test row.converged
            @test row.iterations_mean ≥ 1
        end

        @testset "pendulum needs more Newton iterations at Δt = 1.0 than at Δt = 0.1" begin
            fine   = run_case(pendulum_spec(timespan = (0.0, 20.0), timestep = 0.1),
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

    @testset "Lotka–Volterra (iodeproblem)" begin
        robust  = default_solver_configs()[2]         # Newton/Backtracking
        hermite = first(default_initial_guesses())

        # both the native step (Δt = 0.01) and the coarser Δt = 0.1
        @testset "$name at Δt = $dt" for (name, mk) in
                (("LotkaVolterra2d", lotka_volterra_2d_spec),
                 ("LotkaVolterra4d", lotka_volterra_4d_spec)),
                dt in (0.01, 0.1)
            spec = mk(timespan = (0.0, 2.0), timestep = dt)

            # a robust solver converges at Float64
            row = run_case(spec, Float64, robust, hermite; timing = :none, quiet = true)
            @test row.problem == name
            @test row.converged
            @test row.iterations_mean ≥ 1
            @test row.accuracy === missing            # no analytic reference

            # the grid runs through the IODE path for one precision/guess
            df = run_benchmark(spec; precisions = (Float64,),
                               initial_guesses = default_initial_guesses()[1:1],
                               timing = :none, verbose = false, quiet = true)
            @test nrow(df) == 8
            @test count(df.converged) ≥ 4
        end
    end

    @testset "Hamiltonian systems (hodeproblem)" begin
        robust  = default_solver_configs()[2]         # Newton/Backtracking
        hermite = first(default_initial_guesses())

        # double pendulum at its standard Δt = 0.01 and the coarse Δt = 0.1;
        # Toda lattice (N = 16) at its standard Δt = 0.1 and the coarse Δt = 1.0.
        # Short time spans keep the 16-dimensional implicit solves fast.
        @testset "$name at Δt = $dt" for (name, mk, tspan, dts) in
                (("DoublePendulum", double_pendulum_spec, (0.0, 1.0), (0.01, 0.1)),
                 ("TodaLattice",    toda_lattice_spec,    (0.0, 1.0), (0.1, 1.0))),
                dt in dts
            spec = mk(timespan = tspan, timestep = dt)

            # a robust solver converges at Float64, and the p-aware energy proxy
            # produces a finite drift for these Hamiltonian systems
            row = run_case(spec, Float64, robust, hermite; timing = :none, quiet = true)
            @test row.problem == name
            @test row.converged
            @test row.iterations_mean ≥ 1
            @test row.accuracy === missing            # no analytic reference
            @test row.energy_drift !== missing        # energy needs both q and p

            # the grid runs through the HODE path for one precision/guess
            df = run_benchmark(spec; precisions = (Float64,),
                               initial_guesses = default_initial_guesses()[1:1],
                               timing = :none, verbose = false, quiet = true)
            @test nrow(df) == 8
            @test count(df.converged) ≥ 4
        end

        # The relaxed residual tolerance (`f_abstol_factor = 256`) matters most at
        # reduced precision: with the default `8 eps(T)` the double pendulum's
        # residual floor is unreachable and *no* configuration converges at
        # Float32. Guard that a robust config still converges there.
        # The Toda lattice takes the framework default instead: relaxing it there
        # buys 3 runs of 96 while costing one to two orders of magnitude of
        # residual (see scripts/f_abstol_study.jl).
        @testset "Toda lattice uses the framework default tolerance" begin
            @test toda_lattice_spec().f_abstol_factor == 8
        end

        @testset "double pendulum converges at Float32 (relaxed f_abstol)" begin
            @test double_pendulum_spec().f_abstol_factor == 256
            spec = double_pendulum_spec(timespan = (0.0, 1.0), timestep = 0.01)
            row  = run_case(spec, Float32, robust, hermite; timing = :none, quiet = true)
            @test row.converged
        end
    end

    @testset "NonlinearIntegrators (NonLinear_OneLayer_GML)" begin
        @testset "configuration" begin
            cfgs = nonlinear_solver_configs()
            @test length(cfgs) == 4
            @test solver_label.(cfgs) == ["Newton/Static", "Newton/Backtracking",
                                          "Newton/StrongWolfe", "DogLeg"]
            @test count(c -> c.linesearch === nothing, cfgs) == 1        # DogLeg
            @test nonlinear_regularization_factors() == [0.0, 1e-3, 1e-5, 1e-7]
        end

        # short (10-step) LODE spec; a small dictionary keeps the network solves fast
        spec    = harmonic_oscillator_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)
        newton  = nonlinear_solver_configs()[2]                          # Newton/Backtracking
        method  = nonlinear_onelayer_method(Float64; dict_amount = 100)

        @testset "regularization is required for convergence (Float64)" begin
            # a nonzero regularization factor is essential: the network Newton
            # system is near-singular, so λ = 0 stalls while λ > 0 converges
            reg0 = run_nonlinear_case(spec, Float64, newton, 0.0, method; timing = :none, quiet = true)
            regλ = run_nonlinear_case(spec, Float64, newton, 1e-5, method; timing = :none, quiet = true)
            @test reg0.problem == "HarmonicOscillatorLODE"
            @test !reg0.converged
            @test regλ.converged
            @test regλ.iterations_mean ≥ 1
            @test regλ.accuracy !== missing && regλ.accuracy < 1e-8      # analytic reference available
        end

        @testset "precision sweep runs and records rows" begin
            df = run_nonlinear_benchmark(spec;
                precisions = (Float64, Float32, Float16, BFloat16),
                solver_configs = nonlinear_solver_configs()[[2, 4]],     # Newton/Backtracking, DogLeg
                regularization_factors = [0.0, 1e-5],
                method_builder = T -> nonlinear_onelayer_method(T; dict_amount = 100),
                timing = :none, verbose = false, quiet = true)

            @test nrow(df) == 16                                         # 4 × 2 × 2
            @test all(in(names(df)), ["converged", "iterations_mean", "runtime_s",
                                      "energy_drift", "accuracy", "solver_label", "regularization"])
            # Float64 with regularization converges; both 16-bit formats fail
            # gracefully (singular Jacobian caught and recorded as non-converged
            # rows). BFloat16 fails for want of significand bits, not range: its
            # exponent is as wide as Float32's.
            f64 = df[(df.precision .== "Float64") .& (df.regularization .== "λ = 1e-5"), :]
            @test all(f64.converged)
            for p in ("Float16", "BFloat16")
                low = df[df.precision .== p, :]
                @test nrow(low) == 4 && !any(low.converged)
            end

            st = summary_table(df; panelcol = :regularization)
            @test "regularization" in names(st)
        end

        @testset "a failing method build degrades to non-converged rows" begin
            # The network is built once per precision, outside the per-case error
            # handling, so a precision the constructor cannot handle must not
            # abort the whole sweep.
            df = run_nonlinear_benchmark(spec;
                precisions = (Float64,),
                solver_configs = nonlinear_solver_configs()[[2, 4]],
                regularization_factors = [0.0, 1e-5],
                method_builder = T -> error("no integrator at $T"),
                timing = :none, verbose = false, quiet = true)

            @test nrow(df) == 4                                          # 1 × 2 × 2
            @test !any(df.converged)
            @test all(ismissing, df.max_residual)
            @test Set(df.solver_label) == Set(["Newton/Backtracking", "DogLeg"])
        end

        # the other problems in the study (Lotka–Volterra is excluded — its
        # degenerate Lagrangian is unsupported). The pendulum uses its 2d
        # phase-space iodeproblem; the others use lodeproblems (D = 2 and D = 16).
        # The same (problem-agnostic) network `method` is reused for all of them.
        @testset "$name converges with regularization (Float64)" for (name, mk) in
                (("PendulumLODE",       pendulum_lode_spec),
                 ("DoublePendulumLODE", double_pendulum_lode_spec),
                 ("TodaLatticeLODE",    toda_lattice_lode_spec))
            s   = mk(timespan = (0.0, 1.0), timestep = 0.1)
            row = run_nonlinear_case(s, Float64, newton, 1e-3, method; timing = :none, quiet = true)
            @test row.problem == name
            @test row.converged
            @test row.iterations_mean ≥ 1
            @test row.energy_drift !== missing      # energy proxy needs q and p
            @test row.accuracy === missing          # no analytic reference
        end
    end
end
