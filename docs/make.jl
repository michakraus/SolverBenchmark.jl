using SolverBenchmark
using Documenter

DocMeta.setdocmeta!(SolverBenchmark, :DocTestSetup, :(using SolverBenchmark); recursive=true)

const PAGES = [
    "Home" => "index.md",
    "Implicit Midpoint" => [
        "Harmonic Oscillator" => "harmonic_oscillator.md",
        "Pendulum" => "pendulum.md",
        "Lotka–Volterra (2d)" => "lotka_volterra_2d.md",
        "Lotka–Volterra (4d)" => "lotka_volterra_4d.md",
        "Double Pendulum" => "double_pendulum.md",
        "Toda Lattice" => "toda_lattice.md",
    ],
    "Nonlinear Integrator" => [
        "Harmonic Oscillator" => "nonlinear_harmonic_oscillator.md",
        "Pendulum" => "nonlinear_pendulum.md",
        "Double Pendulum" => "nonlinear_double_pendulum.md",
        "Toda Lattice" => "nonlinear_toda_lattice.md",
    ],
    "Key Findings" => "findings.md",
    "API" => "api.md",
    "Development" => [
        "Internals" => "internals.md",
        "Low-Precision Support" => "precision.md",
        "Maintenance" => "maintenance.md",
    ],
]

# Keep only the entries of a (possibly nested) `pages` list whose source file is in
# `wanted`, dropping sections that end up empty.
function select_pages(pages, wanted)
    kept = Any[]
    for entry in pages
        if entry isa Pair && entry.second isa AbstractVector
            sub = select_pages(entry.second, wanted)
            isempty(sub) || push!(kept, entry.first => sub)
        else
            file = entry isa Pair ? entry.second : entry
            file in wanted && push!(kept, entry)
        end
    end
    kept
end

# `DOCS_PAGES` restricts the build to a comma-separated list of source files. The
# documentation workflow uses it to give every analysis page its own job: that build's
# rendered output is thrown away, and what it is actually for is the sweeps its
# `@example` blocks run, which `cached_sweep` writes to `SOLVERBENCHMARK_SWEEP_CACHE`
# for the job that assembles the real site. Because the omitted pages are genuinely
# absent, their cross-references cannot resolve, so a partial build only warns.
const wanted  = filter(!isempty, strip.(split(get(ENV, "DOCS_PAGES", ""), ",")))
const partial = !isempty(wanted)
const pages   = partial ? select_pages(PAGES, wanted) : PAGES

partial && isempty(pages) && error("DOCS_PAGES matched no page: $(join(wanted, ", "))")

makedocs(;
    modules=[SolverBenchmark],
    authors="Michael Kraus",
    sitename="SolverBenchmark.jl",
    format=Documenter.HTML(;
        canonical="https://michakraus.github.io/SolverBenchmark.jl",
        edit_link="main",
        assets=String[],
        # analysis pages embed several figures as base64, exceeding the default limit
        size_threshold=2_000_000,
        size_threshold_warn=1_000_000,
    ),
    pages,
    # `pages` only builds the navigation: without this, Documenter expands *every* `.md`
    # under `docs/src`, so a partial build would run every sweep in the study rather than
    # the one page's. Every page is listed above, so this discards nothing in a full build.
    pagesonly=true,
    warnonly=partial,
)

# Publish a complete site only. `DEPLOY_DOCS` is how the workflow withholds a
# deployment when some sweep job failed: a partial deployment would silently drop
# pages from the published documentation.
if !partial && get(ENV, "DEPLOY_DOCS", "true") == "true"
    deploydocs(;
        repo="github.com/michakraus/SolverBenchmark.jl",
        devbranch="main",
    )
end
