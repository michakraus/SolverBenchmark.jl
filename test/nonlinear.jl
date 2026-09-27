using SolverBenchmark
using DataFrames
using Test

@testset "NonlinearIntegrators (ShallowNet)" begin
    @testset "configuration" begin
        cfgs = nonlinear_solver_configs()
        @test length(cfgs) == 4
        @test solver_label.(cfgs) == ["Newton/Static", "Newton/Backtracking",
            "Newton/StrongWolfe", "DogLeg"]
        @test count(c -> c.linesearch === nothing, cfgs) == 1        # DogLeg

        regs = nonlinear_regularization_factors()
        @test length(regs) == 7                                      # λ = 0 + six rungs
        @test [r.name for r in regs] ==
              ["λ = 0"; ["λ rung $r" for r in 1:6]]
        @test regs[1].rung === nothing                               # the control
        @test [r.rung for r in regs[2:end]] == collect(1:6)
    end

    # The two ladders, pinned as a table. `Float64` gets its own because √eps
    # spans four orders of magnitude across the formats; both ladders contain
    # 16√eps(T) — NonlinearIntegrators' recommended default — so this also
    # guards against either one drifting off that anchor.
    @testset "regularization ladder scales with the precision" begin
        rungs = nonlinear_regularization_factors()[2:end]
        expected = Dict(BFloat16 => (1, 2, 3, 4, 5, 6), Float16 => (1, 2, 3, 4, 5, 6),
            Float32 => (1, 2, 3, 4, 5, 6), Float64 => (2, 4, 6, 8, 10, 12))
        for (T, ks) in expected, (i, k) in enumerate(ks)

            @test regularization_exponent(T, i) == k
            λ = rungs[i].factor(T)
            @test λ isa T                       # no silent upcast to Float64
            @test isfinite(λ)                   # `T(2)^k` would overflow Float16 at k ≥ 16
            @test λ == T(2.0^k * sqrt(Float64(eps(T))))
        end
        # the 16√eps(T) anchor: rung 4 at reduced precision, rung 2 at Float64
        @test rungs[4].factor(Float16) == Float16(0.5)
        @test rungs[4].factor(Float32) ≈ 16 * sqrt(eps(Float32))
        @test rungs[2].factor(Float64) ≈ 16 * sqrt(eps(Float64))
        # a rung off the ladder is an error, not a silent `BoundsError` later
        @test_throws ArgumentError scaled_regularization(0)
        @test_throws ArgumentError scaled_regularization(7)

        # a bare number still means "the same factor at every precision"
        fixed = RegularizationConfig(1e-5)
        @test fixed.name == "λ = 1e-5"
        @test fixed.rung === nothing
        @test fixed.factor(Float32) == Float32(1e-5)
    end

    # short (10-step) LODE spec; a small dictionary keeps the network solves fast
    spec = harmonic_oscillator_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)
    newton = nonlinear_solver_configs()[2]                          # Newton/Backtracking
    method = nonlinear_onelayer_method(Float64; dict_amount = 100)

    @testset "regularization is required for convergence (Float64)" begin
        # a nonzero regularization factor is essential: the network Newton
        # system is near-singular, so λ = 0 stalls while λ > 0 converges
        reg0 = run_nonlinear_case(
            spec, Float64, newton, 0.0, method; timing = :none, quiet = true)
        regλ = run_nonlinear_case(
            spec, Float64, newton, 1e-5, method; timing = :none, quiet = true)
        @test reg0.problem == "HarmonicOscillatorLODE"
        @test !reg0.converged
        @test regλ.converged
        @test regλ.iterations_mean ≥ 1
        @test regλ.accuracy !== missing && regλ.accuracy < 1e-8      # analytic reference available

        # the same through the ladder: rung 2 is 16√eps(Float64), the value
        # NonlinearIntegrators recommends
        rung2 = run_nonlinear_case(spec, Float64, newton,
            nonlinear_regularization_factors()[3], method;
            timing = :none, quiet = true)
        @test rung2.regularization == "λ rung 2"
        @test rung2.regularization_exponent == 4
        @test rung2.regularization_factor ≈ 16 * sqrt(eps(Float64))
        @test rung2.converged
        @test rung2.accuracy < 1e-8
    end

    @testset "precision sweep runs and records rows" begin
        regs = nonlinear_regularization_factors()[[1, 3]]             # λ = 0, rung 2
        df = run_nonlinear_benchmark(spec;
            precisions = (Float64, Float32, Float16, BFloat16),
            solver_configs = nonlinear_solver_configs()[[2, 4]],     # Newton/Backtracking, DogLeg
            regularization_factors = regs,
            method_builder = T -> nonlinear_onelayer_method(T; dict_amount = 100),
            timing = :none, verbose = false, quiet = true)

        @test nrow(df) == 16                                         # 4 × 2 × 2
        @test all(in(names(df)),
            ["converged", "iterations_mean", "runtime_s",
                "energy_drift", "accuracy", "solver_label",
                "regularization", "regularization_exponent",
                "regularization_factor"])
        # the panel label is shared across precisions, but the shift behind it is
        # not: the same rung is a different multiple of √eps at Float64
        rung2 = df[df.regularization .== "λ rung 2", :]
        @test all(ismissing, df[df.regularization .== "λ = 0", :].regularization_exponent)
        @test only(unique(rung2[rung2.precision .== "Float64", :].regularization_exponent)) ==
              4
        @test only(unique(rung2[rung2.precision .== "Float32", :].regularization_exponent)) ==
              2

        # Float64 with regularization converges; both 16-bit formats fail
        # gracefully. Their failure is *not* the regularized Newton solve — it is
        # the OGA seed's Gram matrix, which is rank-deficient by the third neuron
        # at 16 bits, so it happens before `regularization_factor` is ever
        # applied and no rung of the ladder can lift it.
        f64 = rung2[rung2.precision .== "Float64", :]
        @test all(f64.converged)
        for p in ("Float16", "BFloat16")
            low = df[df.precision .== p, :]
            @test nrow(low) == 4 && !any(low.converged)
            @test all(ismissing, low.max_residual)                   # threw, did not stall
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
            # mixed bare `Real` and `RegularizationConfig`: both are accepted,
            # and the failing-build branch has to label either kind of row
            regularization_factors = [0.0, nonlinear_regularization_factors()[3]],
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
    @testset "$name converges with regularization (Float64)" for (name, mk) in ((
        "PendulumLODE", pendulum_lode_spec),
        ("DoublePendulumLODE", double_pendulum_lode_spec),
        ("TodaLatticeLODE", toda_lattice_lode_spec))
        s = mk(timespan = (0.0, 1.0), timestep = 0.1)
        # rung 2 = 16√eps(Float64); measured, every rung converges here and
        # λ = 0 converges on none of the three
        reg = nonlinear_regularization_factors()[3]
        row = run_nonlinear_case(
            s, Float64, newton, reg, method; timing = :none, quiet = true)
        @test row.problem == name
        @test row.converged
        @test row.iterations_mean ≥ 1
        @test row.energy_drift !== missing      # energy proxy needs q and p
        @test row.accuracy === missing          # no analytic reference
    end
end
