using SolverBenchmark
using DataFrames
using Test

@testset "Lotka–Volterra (iodeproblem)" begin
    robust = default_solver_configs()[2]         # Newton/Backtracking
    hermite = first(default_initial_guesses())

    # both the native step (Δt = 0.01) and the coarser Δt = 0.1
    @testset "$name at Δt = $dt" for (name, mk) in ((
            "LotkaVolterra2d", lotka_volterra_2d_spec),
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
    robust = default_solver_configs()[2]         # Newton/Backtracking
    hermite = first(default_initial_guesses())

    # double pendulum at its standard Δt = 0.01 and the coarse Δt = 0.1;
    # Toda lattice (N = 16) at its standard Δt = 0.1 and the coarse Δt = 1.0.
    # Short time spans keep the 16-dimensional implicit solves fast.
    @testset "$name at Δt = $dt" for (name, mk, tspan, dts) in ((
            "DoublePendulum", double_pendulum_spec, (0.0, 1.0), (0.01, 0.1)),
            ("TodaLattice", toda_lattice_spec, (0.0, 1.0), (0.1, 1.0))),
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
        row = run_case(spec, Float32, robust, hermite; timing = :none, quiet = true)
        @test row.converged
    end
end
