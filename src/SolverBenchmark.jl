module SolverBenchmark

using BenchmarkTools
using CairoMakie
using DataFrames
using Logging
using Printf
import Markdown

using GeometricIntegrators
using GeometricProblems
using SimpleSolvers

# `GeometricIntegratorsBase` provides the low-level stepping API
# (`solutionstep`, `solverstate`, `current`, …) that is needed to drive the
# integrator step-by-step and read the nonlinear-solver statistics after every
# time step. These functions are not re-exported by `GeometricIntegrators`, so
# we access them through this alias.
import GeometricIntegratorsBase as GIB

import GeometricProblems.HarmonicOscillator
import GeometricProblems.Pendulum
import GeometricProblems.LotkaVolterra2d
import GeometricProblems.LotkaVolterra4d
import GeometricProblems.DoublePendulum
import GeometricProblems.TodaLattice

# problem definitions
export ProblemSpec, harmonic_oscillator_spec, pendulum_spec
export lotka_volterra_2d_spec, lotka_volterra_4d_spec
export double_pendulum_spec, toda_lattice_spec

# benchmark configuration
export SolverConfig, InitialGuessConfig
export default_solver_configs, default_initial_guesses, default_precisions
export solver_label

# running the benchmark
export run_case, run_benchmark

# post-processing
export summary_table, markdown_table
export comparison_figure, plot_convergence, plot_iterations, plot_runtime, plot_energy_drift, plot_accuracy

include("problems.jl")
include("configurations.jl")
include("benchmark.jl")
include("plots.jl")

end
