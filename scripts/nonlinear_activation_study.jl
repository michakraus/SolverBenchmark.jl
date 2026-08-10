# Activation & seed study for the NonLinear_OneLayer_GML integrator.
#
# Question: the production default, ReLU^k with the `OGA1d_Legacy` seed, fails at
# Float16 (the Newton Jacobian hits a SingularException). Does the
# working-precision QR seed `OGA1d`, paired with a smooth activation, fix Float16
# without giving up Float64 accuracy? The matrix below answers it by varying seed
# and activation independently.
#
# This is a standalone study: it injects `activation` / `initial_guess_method` into
# `nonlinear_onelayer_method` via the `method_builder` hook and does NOT change the
# committed production benchmark defaults (ReLU^k + OGA1d_Legacy).
#
# Only OGA seeds are compared. Gradient-training seeds are not pursued:
# `TrainingMethod` runs a per-step Adam loop (not viable in practice) and `LSGD`
# has no `initial_params!` for the one-layer method. A proposed 2-D OGA dictionary
# better suited to smooth activations is documented in ../oga.md.
#
# Run from the repo root:
#     julia --project=. scripts/nonlinear_activation_study.jl

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using SolverBenchmark
using CSV
using DataFrames
using PrettyTables
using Printf
using NonlinearIntegrators: OGA1d, OGA1d_Legacy

# (label, activation, seed). The relu3 rows anchor the study: relu3_OGA1d isolates
# the seed change (activation held fixed), relu3_OGA1dLeg reproduces the current
# production benchmark.
const ACTIVATION_MATRIX = [
    ("relu3_OGA1d",    relu_k(3), OGA1d()),
    ("relu3_OGA1dLeg", relu_k(3), OGA1d_Legacy()),
    ("elu_OGA1d",      elu,       OGA1d()),
    ("gelu_OGA1d",     gelu,      OGA1d()),
]

# Fast, decisive slice: HO has an analytic reference (accuracy populated — the
# clearest Float16 signal); the double pendulum is where OGA1d regresses hardest.
activation_study_specs() = [
    harmonic_oscillator_lode_spec(; timestep = 0.1, timespan = (0.0, 1.0)),
    double_pendulum_lode_spec(;    timestep = 0.1, timespan = (0.0, 1.0)),
]

method_builder(activation, seed) =
    T -> nonlinear_onelayer_method(T; activation = activation, initial_guess_method = seed)

# Rank key for picking the representative row within a (problem, activation,
# precision) group: converged first, then smallest residual, then fewest
# iterations. `missing` sorts last.
_rank_num(x) = ismissing(x) ? Inf : Float64(x)

const _PRECISION_RANK = Dict("BFloat16" => 1, "Float16" => 2, "Float32" => 3, "Float64" => 4)

"""
    best_rows(df)

Reduce `df` to one representative row per (problem, activation, precision) group,
choosing the converged row with the smallest `max_residual` (ties broken by
`iterations_mean`). Keeps only the columns relevant to the convergence comparison.
"""
function best_rows(df::DataFrame)
    parts = DataFrame[]
    for g in groupby(df, [:problem, :activation, :precision])
        gg = DataFrame(g)
        sort!(gg, [DataFrames.order(:converged, rev = true),
                   DataFrames.order(:max_residual,    by = _rank_num),
                   DataFrames.order(:iterations_mean, by = _rank_num)])
        row = gg[1:1, :]
        # keep how many of the (solver × λ) configs converged in this cell, so a
        # single best row still shows breadth of convergence (e.g. 24/28 vs 0/28)
        row.n_converged = [count(gg.converged)]
        row.n_total = [nrow(gg)]
        push!(parts, row)
    end
    best = vcat(parts...)
    best = select(best, [:problem, :activation, :precision, :converged,
                         :n_converged, :n_total, :max_residual, :iterations_mean, :accuracy])
    sort!(best, [:problem, :activation,
                 DataFrames.order(:precision, by = p -> get(_PRECISION_RANK, p, 99))])
    best
end

function run_activation_study(; resultsdir = joinpath(@__DIR__, "..", "results"),
                              specs = activation_study_specs(),
                              matrix = ACTIVATION_MATRIX,
                              precisions = default_precisions(),
                              solver_configs = nonlinear_solver_configs(),
                              regularization_factors = nonlinear_regularization_factors())
    mkpath(resultsdir)
    rows = DataFrame[]

    for spec in specs, (label, activation, seed) in matrix, T in precisions
        # Each (activation × precision) is its own benchmark call wrapped in
        # try/catch: the activation is traced at method-build time (outside
        # run_nonlinear_case's own try/catch), so a tracing failure — most likely
        # ELU on the symbolic path — is contained to that one cell instead of
        # aborting the whole study.
        @info "activation study" problem = spec.name activation = label precision = T
        try
            df = run_nonlinear_benchmark(spec;
                method_builder = method_builder(activation, seed),
                precisions = (T,), solver_configs, regularization_factors,
                timing = :quick, verbose = false, quiet = true)
            df.activation = fill(label, nrow(df))
            push!(rows, df)
        catch err
            @warn "activation cell failed" problem = spec.name activation = label precision = T exception = err
        end
    end

    combined = vcat(rows...; cols = :union)

    csvpath = joinpath(resultsdir, "nonlinear_activation_study.csv")
    CSV.write(csvpath, combined)

    best = best_rows(combined)
    println("\n=== activation & seed study: best row per (problem, activation, precision) ===")
    pretty_table(best)

    mdpath = joinpath(resultsdir, "nonlinear_activation_study.md")
    open(mdpath, "w") do io
        println(io, "# Activation & seed study\n")
        println(io, markdown_table(best))
    end

    @info "activation study complete" csv = csvpath markdown = mdpath rows = nrow(combined)
    return combined, best
end

run_activation_study()
