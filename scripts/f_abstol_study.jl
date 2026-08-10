# Compare the relaxed solver tolerance `f_abstol_factor = 256` against the
# framework default `8 eps(T)` for the specs that carry the override.
#
#     julia --project=. scripts/f_abstol_study.jl
#
# The override exists because on some problems several configurations report
# non-convergence at `8 eps(T)` even though the step is fully solved. This script
# tests that claim per spec: it runs the full sweep at both factors and prints
# converged-run counts and the residual range, so the override can be kept only where
# it earns its keep.
#
# Writes `results/f_abstol_study.md`.

using SolverBenchmark
using DataFrames
using Printf
import Markdown

const RESULTS = joinpath(@__DIR__, "..", "results")
mkpath(RESULTS)

# A copy of `spec` with a different residual tolerance factor.
retune(spec::ProblemSpec, factor) =
    ProblemSpec(spec.name, spec.builder, spec.energy, spec.reference; f_abstol_factor = factor)

const FACTORS = (8, 256)

_range(xs) = isempty(xs) ? "—" : @sprintf("%.1e … %.1e", minimum(xs), maximum(xs))

function summarise(label, df, factor)
    rows = []
    for p in ["BFloat16", "Float16", "Float32", "Float64"]
        sub = df[df.precision .== p, :]
        isempty(sub) && continue
        ok  = sub[sub.converged, :]
        res = collect(skipmissing(ok.max_residual))
        push!(rows, (case = label, factor = factor, precision = p,
                     converged = "$(nrow(ok))/$(nrow(sub))",
                     residual = _range(res)))
    end
    rows
end

rows = []

# Julia buffers stdout/stderr when they are redirected to a file, so progress is
# printed explicitly and flushed: that way a run that has to be interrupted still
# shows how far it got, and any warning the runtime writes (which is *not*
# buffered) can be attributed to the sweep it came from.
function sweep(label, factor, run)
    println("### $label  f_abstol_factor = $factor"); flush(stdout); flush(stderr)
    df = run()
    println("    converged $(count(df.converged))/$(nrow(df))"); flush(stdout); flush(stderr)
    df
end

# --- implicit midpoint -------------------------------------------------------

const MIDPOINT_CASES = [
    ("DoublePendulum Δt=0.01", double_pendulum_spec(timespan = (0.0, 10.0), timestep = 0.01)),
    ("DoublePendulum Δt=0.1",  double_pendulum_spec(timespan = (0.0, 10.0), timestep = 0.1)),
    ("TodaLattice Δt=0.1",     toda_lattice_spec(timespan = (0.0, 100.0), timestep = 0.1)),
    ("TodaLattice Δt=1.0",     toda_lattice_spec(timespan = (0.0, 100.0), timestep = 1.0)),
]

for (label, spec) in MIDPOINT_CASES, factor in FACTORS
    df = sweep(label, factor, () ->
        run_benchmark(retune(spec, factor); timing = :none, verbose = false, quiet = true))
    append!(rows, summarise(label, df, factor))
end

# --- nonlinear integrator ----------------------------------------------------
#
# Only Δt = 0.1 is swept: Δt = 1.0 and 10.0 converge nowhere at either factor, so
# they cannot discriminate between them.

const NONLINEAR_CASES = [
    ("HarmonicOscillatorLODE Δt=0.1", harmonic_oscillator_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)),
    ("PendulumLODE Δt=0.1",           pendulum_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)),
    ("DoublePendulumLODE Δt=0.1",     double_pendulum_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)),
    ("TodaLatticeLODE Δt=0.1",        toda_lattice_lode_spec(timespan = (0.0, 1.0), timestep = 0.1)),
]

for (label, spec) in NONLINEAR_CASES, factor in FACTORS
    df = sweep(label, factor, () ->
        run_nonlinear_benchmark(retune(spec, factor); timing = :none, verbose = false, quiet = true))
    append!(rows, summarise(label, df, factor))
end

# --- report ------------------------------------------------------------------

out = DataFrame(rows)
show(stdout, out; allrows = true, allcols = true)
println()

open(joinpath(RESULTS, "f_abstol_study.md"), "w") do io
    println(io, "# `f_abstol_factor`: 8 vs. 256\n")
    println(io, "Converged runs and the residual range over the converged runs, ")
    println(io, "for the specs that override the framework default.\n")
    print(io, markdown_table(out))
end
