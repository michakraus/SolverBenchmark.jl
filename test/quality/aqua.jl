using Aqua
using SolverBenchmark
using Test

# `src/bfloat16.jl` adds `Base` and `NaNMath` methods for `BFloat16` that upstream
# lacks, which Aqua reports as piracy.
Aqua.test_all(SolverBenchmark; piracies = (; broken = true))  # issue #29
