using SafeTestsets

const GROUPS = isempty(ARGS) ? ["core", "slow"] : ARGS

if "core" in GROUPS
    @safetestset "Aqua" include("quality/aqua.jl")
    @safetestset "Configurations" include("configurations.jl")
    @safetestset "Benchmark runs" include("benchmark.jl")
    @safetestset "Problems" include("problems.jl")
    @safetestset "NonlinearIntegrators (ShallowNet)" include("nonlinear.jl")
    @safetestset "cached_sweep" include("cache.jl")
end
