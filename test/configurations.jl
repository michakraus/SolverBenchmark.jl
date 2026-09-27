using SolverBenchmark
using Test

@testset "configurations" begin
    cfgs = default_solver_configs()
    @test length(cfgs) == 8
    @test count(c -> c.solver_name == "Newton", cfgs) == 6
    @test count(c -> c.linesearch === nothing, cfgs) == 2   # DogLeg, Picard
    @test solver_label(cfgs[1]) == "Newton/Static"
    @test default_precisions() == (BFloat16, Float16, Float32, Float64)
    @test length(default_initial_guesses()) == 3
end
