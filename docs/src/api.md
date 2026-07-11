```@meta
CurrentModule = SolverBenchmark
```

# API

The benchmark harness is intentionally decoupled from any particular problem or
integrator, so new examples and integrators can be added easily. A problem is
described by a [`ProblemSpec`](@ref); the sweep is defined by a list of
[`SolverConfig`](@ref)s and [`InitialGuessConfig`](@ref)s and executed by
[`run_benchmark`](@ref); the results are post-processed with
[`summary_table`](@ref) and the plotting helpers.

```@index
```

```@autodocs
Modules = [SolverBenchmark]
```
