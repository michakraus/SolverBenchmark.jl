# Shared driver for a single nonlinear-integrator benchmark analysis
# (NonLinear_OneLayer_GML). Mirrors `analysis.jl` but sweeps the solver
# `regularization_factor` in place of the initial guess, so the figures and the
# summary table panel by `:regularization`.
#
# Run one of the nonlinear problem scripts (which `include` this file), e.g.
#     julia --project=. scripts/nonlinear_harmonic_oscillator.jl

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using SolverBenchmark
using CairoMakie
using CSV
using DataFrames
using PrettyTables
import GeometricIntegratorsBase as GIB

function run_nonlinear_analysis(spec::ProblemSpec;
                                timing::Symbol = :benchmark,
                                resultsdir = joinpath(@__DIR__, "..", "results"))
    mkpath(resultsdir)
    # include the time step in the file names so runs at different Δt do not clash
    Δt = GIB.timestep(spec.builder(Float64))
    stem = "$(lowercase(spec.name))_dt$(Δt)"

    @info "Running nonlinear benchmark" problem = spec.name timing
    df = run_nonlinear_benchmark(spec; timing)

    # raw results
    csvpath = joinpath(resultsdir, "$(stem).csv")
    CSV.write(csvpath, df)

    # printed summary
    println("\n=== $(spec.name) (Δt = $Δt): summary ===")
    pretty_table(summary_table(df; panelcol = :regularization))
    println("converged: $(count(df.converged)) / $(nrow(df))\n")

    # figures — panelled by regularization factor
    figures = [
        "convergence" => plot_convergence(df;  panelcol = :regularization, title = spec.name),
        "iterations"  => plot_iterations(df;   panelcol = :regularization, title = spec.name),
        "runtime"     => plot_runtime(df;      panelcol = :regularization, title = spec.name),
        "energy"      => plot_energy_drift(df; panelcol = :regularization, title = spec.name),
    ]
    any(!ismissing, df.accuracy) &&
        push!(figures, "accuracy" => plot_accuracy(df; panelcol = :regularization, title = spec.name))

    for (name, fig) in figures
        save(joinpath(resultsdir, "$(stem)_$(name).png"), fig)
    end

    @info "analysis complete" csv = csvpath figures = length(figures)
    return df
end
