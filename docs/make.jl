using SolverBenchmark
using Documenter

DocMeta.setdocmeta!(SolverBenchmark, :DocTestSetup, :(using SolverBenchmark); recursive=true)

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
    pages=[
        "Home" => "index.md",
        "Analyses" => [
            "Harmonic Oscillator" => "harmonic_oscillator.md",
            "Pendulum" => "pendulum.md",
            "Lotka–Volterra (2d)" => "lotka_volterra_2d.md",
            "Lotka–Volterra (4d)" => "lotka_volterra_4d.md",
            "Double Pendulum" => "double_pendulum.md",
            "Toda Lattice" => "toda_lattice.md",
        ],
        "API" => "api.md",
    ],
)

deploydocs(;
    repo="github.com/michakraus/SolverBenchmark.jl",
    devbranch="main",
)
