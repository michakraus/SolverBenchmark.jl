# Shared driver for a single benchmark analysis.
#
# Run one of the problem scripts (which `include` this file), e.g.
#     julia --project=. scripts/harmonic_oscillator.jl
# Each analysis runs the full benchmark grid with accurate `BenchmarkTools`
# timing, writes the raw results to `results/<problem>.csv`, prints a summary
# table, and saves the comparison figures to `results/`.

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using SolverBenchmark
using CairoMakie
using CSV
using DataFrames
using PrettyTables
import GeometricIntegratorsBase as GIB

function run_analysis(spec::ProblemSpec;
                      timing::Symbol = :benchmark,
                      resultsdir = joinpath(@__DIR__, "..", "results"))
    mkpath(resultsdir)
    # include the time step in the file names so runs at different Δt do not clash
    Δt = GIB.timestep(spec.builder(Float64))
    stem = "$(lowercase(spec.name))_dt$(Δt)"

    @info "Running benchmark" problem = spec.name timing
    df = run_benchmark(spec; timing)

    # raw results
    csvpath = joinpath(resultsdir, "$(stem).csv")
    CSV.write(csvpath, df)

    # printed summary
    println("\n=== $(spec.name): summary ===")
    pretty_table(summary_table(df))
    println("converged: $(count(df.converged)) / $(nrow(df))\n")

    # figures
    figures = [
        "convergence" => plot_convergence(df; title = spec.name),
        "iterations"  => plot_iterations(df;  title = spec.name),
        "runtime"     => plot_runtime(df;     title = spec.name),
        "energy"      => plot_energy_drift(df; title = spec.name),
    ]
    any(!ismissing, df.accuracy) && push!(figures, "accuracy" => plot_accuracy(df; title = spec.name))

    for (name, fig) in figures
        save(joinpath(resultsdir, "$(stem)_$(name).png"), fig)
    end

    @info "analysis complete" csv = csvpath figures = length(figures)
    return df
end
