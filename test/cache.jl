using SolverBenchmark
using DataFrames
using Test

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
