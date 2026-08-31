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

    @testset "NonlinearIntegrators (NonLinear_OneLayer_GML)" begin
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

    # The documentation workflow computes each page's sweeps in its own job and hands
    # the CSVs to the job that renders the site, so the round trip has to preserve
    # everything the plots and tables read.
    @testset "cached_sweep" begin
        spec = harmonic_oscillator_spec(timespan = (0.0, 1.0), timestep = 0.1)
        sweep() = run_benchmark(spec; precisions = (Float64,), timing = :none,
            verbose = false, quiet = true)

        @testset "no cache configured is a plain call" begin
            withenv("SOLVERBENCHMARK_SWEEP_CACHE" => nothing) do
                @test sweep_cache_dir() === nothing
                calls = 0
                df = cached_sweep("unused") do
                    calls += 1
                    DataFrame(a = [1, 2, 3])
                end
                @test calls == 1 && nrow(df) == 3
                # nothing is written, so a local build cannot pick up a stale sweep
                @test !isdir("unused")
            end
        end

        @testset "computes once, then reads back" begin
            mktempdir() do dir
                withenv("SOLVERBENCHMARK_SWEEP_CACHE" => dir) do
                    @test sweep_cache_dir() == dir
                    calls = 0
                    compute() = (calls += 1; sweep())

                    a = cached_sweep(compute, "probe")
                    @test calls == 1
                    @test isfile(joinpath(dir, "probe.csv"))

                    b = cached_sweep(compute, "probe")
                    @test calls == 1                       # the second call hit the cache
                    @test names(a) == names(b)
                    @test nrow(a) == nrow(b)
                    @test count(a.converged) == count(b.converged)
                    @test eltype(b.converged) == Bool      # not "true"/"false" strings
                    @test b.precision == a.precision       # matched by string equality

                    # the round-tripped frame has to drive the plots and tables unchanged
                    @test summary_table(b) isa DataFrame
                    # `Makie` is not a test dependency, so check the type by name
                    @test nameof(typeof(plot_convergence(b))) === :Figure
                    # `accuracy` is present here; a column that is entirely `missing`
                    # comes back as `Missing`, which `drop_empty` already handles
                    @test any(!ismissing, b.accuracy)
                end
            end
        end

        # `SOLVERBENCHMARK_SWEEPS` is what splits a page finer than the page: the job that
        # owns one time step computes that sweep and declines the page's others.
        @testset "selection computes only the named sweeps" begin
            mktempdir() do dir
                withenv("SOLVERBENCHMARK_SWEEP_CACHE" => dir,
                    "SOLVERBENCHMARK_SWEEPS" => "wanted,also_wanted") do
                    @test selected_sweeps() == Set(["wanted", "also_wanted"])

                    @test nrow(cached_sweep(() -> DataFrame(a = [1]), "wanted")) == 1
                    @test isfile(joinpath(dir, "wanted.csv"))

                    # an unselected key is declined rather than computed, and nothing is
                    # written for it — the job that owns it writes it
                    @test_throws SweepNotSelected cached_sweep("other") do
                        error("must not be computed")
                    end
                    @test !isfile(joinpath(dir, "other.csv"))

                    # ... unless it is already cached, which is the `documenter` job's case
                    cp(joinpath(dir, "wanted.csv"), joinpath(dir, "other.csv"))
                    @test nrow(cached_sweep(() -> error("cached"), "other")) == 1
                end
            end
        end

        @testset "no selection computes anything asked for" begin
            mktempdir() do dir
                withenv("SOLVERBENCHMARK_SWEEP_CACHE" => dir,
                    "SOLVERBENCHMARK_SWEEPS" => nothing) do
                    @test selected_sweeps() === nothing
                    @test nrow(cached_sweep(() -> DataFrame(a = [1, 2]), "anything")) == 2
                end
            end
        end

        @testset "distinct keys do not collide" begin
            mktempdir() do dir
                withenv("SOLVERBENCHMARK_SWEEP_CACHE" => dir) do
                    cached_sweep(() -> DataFrame(a = [1]), "one")
                    cached_sweep(() -> DataFrame(a = [2]), "two")
                    @test nrow(cached_sweep(() -> error("recomputed"), "one")) == 1
                    @test cached_sweep(() -> error("recomputed"), "two").a == [2]
                end
            end
        end
    end
end
