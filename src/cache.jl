# The documentation build runs every sweep in the study — twelve implicit-midpoint and
# twelve nonlinear ones — which is more work than one CI job should carry. `cached_sweep`
# is the seam that lets the documentation workflow split it: each page's sweeps are
# computed in their own parallel job, which writes them here, and the job that assembles
# the site reads them back instead of recomputing.
#
# Entries are addressed by an explicit key rather than by hashing the arguments. A hash
# would invite carrying the cache between commits, and a stale hit would publish numbers
# that no longer match the code — the one failure mode this must not have. The workflow
# builds the cache from scratch on every run and never restores it from a previous one.

"""
    sweep_cache_dir()

The directory holding cached benchmark sweeps, taken from the
`SOLVERBENCHMARK_SWEEP_CACHE` environment variable, or `nothing` when that is unset.
"""
function sweep_cache_dir()
    dir = get(ENV, "SOLVERBENCHMARK_SWEEP_CACHE", "")
    isempty(dir) ? nothing : dir
end

"""
    selected_sweeps()

The set of sweep keys this build is asked to compute, from the comma-separated
`SOLVERBENCHMARK_SWEEPS` environment variable, or `nothing` when it is unset — meaning
"compute whatever is asked for".

This is what splits a page finer than the page itself. The nonlinear pages carry three
sweeps each and are the slowest jobs in the documentation build, so the workflow gives
each of their time steps its own job, selecting one key per job.
"""
function selected_sweeps()
    keys = get(ENV, "SOLVERBENCHMARK_SWEEPS", "")
    isempty(keys) ? nothing : Set(strip.(split(keys, ",")))
end

"""
    SweepNotSelected(key)

Thrown by [`cached_sweep`](@ref) for a sweep that is neither cached nor selected by
[`selected_sweeps`](@ref) — the other sweeps of a page whose job was given one of them.

A job that raises this is doing its job: it computed its own sweep and declined the
rest. Documenter is called with `warnonly` for such a build, so the blocks that go on
to use the missing `DataFrame` are reported as warnings and the build still succeeds,
which is all that is wanted from it — the rendered output is discarded and only the
written CSVs are kept.
"""
struct SweepNotSelected <: Exception
    key::String
end

function Base.showerror(io::IO, e::SweepNotSelected)
    print(io,
        "sweep \"", e.key, "\" is not cached and not selected by SOLVERBENCHMARK_SWEEPS")
end

"""
    cached_sweep(compute, key)

Return the benchmark `DataFrame` for `key`: read from [`sweep_cache_dir`](@ref) if it
holds `<key>.csv`, otherwise computed by `compute()` and written there. Written for
`do` block syntax:

```julia
df = cached_sweep("harmonic_oscillator_dt0.1") do
    run_benchmark(spec; timing = :quick, verbose = false, quiet = true)
end
```

With no cache directory configured this is exactly `compute()`, so a local
`julia --project=docs docs/make.jl` runs every sweep just as it would without the
cache. The documentation workflow sets the directory, computes each page's sweeps in
its own job, and hands the CSVs to the job that renders the site.

The round trip through CSV is lossless for everything the plots and
[`summary_table`](@ref) read: `missing` comes back as `missing`, and a column that is
entirely `missing` (`accuracy` on a problem with no analytic reference) comes back as
`Missing`, which is what `drop_empty` and `any(!ismissing, ...)` already expect.

Throws [`SweepNotSelected`](@ref) for a key that is neither cached nor listed in
[`selected_sweeps`](@ref), which is how a job computes one of a page's sweeps and
declines the others.
"""
function cached_sweep(compute, key::AbstractString)
    dir = sweep_cache_dir()
    dir === nothing && return compute()

    path = joinpath(dir, "$key.csv")
    isfile(path) && return DataFrame(CSV.File(path))

    selected = selected_sweeps()
    selected === nothing || key in selected || throw(SweepNotSelected(key))

    df = compute()
    mkpath(dir)
    CSV.write(path, df)
    df
end
