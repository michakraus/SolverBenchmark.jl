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
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/michakraus/SolverBenchmark.jl",
    devbranch="main",
)
