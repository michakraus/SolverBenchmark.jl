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
"""
function cached_sweep(compute, key::AbstractString)
    dir = sweep_cache_dir()
    dir === nothing && return compute()

    path = joinpath(dir, "$key.csv")
    isfile(path) && return DataFrame(CSV.File(path))

    df = compute()
    mkpath(dir)
    CSV.write(path, df)
    df
end
