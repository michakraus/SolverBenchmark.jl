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
        @test default_precisions() == (Float16, Float32, Float64)
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
        for T in (Float16, Float32)
            row = run_case(spec, T, scfg, hermite; timing = :none, quiet = true)
            @test row.precision == string(T)
            @test row.converged                        # linear problem converges at every precision
        end
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
        @testset "double pendulum converges at Float32 (relaxed f_abstol)" begin
            @test double_pendulum_spec().f_abstol_factor == 256
            spec = double_pendulum_spec(timespan = (0.0, 1.0), timestep = 0.01)
            row  = run_case(spec, Float32, robust, hermite; timing = :none, quiet = true)
            @test row.converged
        end
    end
end
