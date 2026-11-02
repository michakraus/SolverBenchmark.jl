# Reproducer for `KNOWN_ISSUES.md` K7: `Picard` and the implicit-midpoint residual use
# opposite sign conventions.
#
#     julia --project=. scripts/picard_residual_sign.jl
#
# SimpleSolvers' `Picard` steps `x ← x - F(x)`, which is the fixed-point iteration
# `x ← Φ(x)` only for a residual written as `F(x) = x - Φ(x)`. GeometricIntegratorsBase's
# `ImplicitMidpoint` hands the solver `F(x) = Φ(x) - x` (`b .= v .- x`), so the step is
# `x ← 2x - Φ(x)`, whose iteration matrix `2I - J_Φ` has spectral radius near 2 for a
# contraction `Φ`. The safeguard then halves the step until it underflows, the iterate
# freezes and the solve stops after about two iterations per time step.
#
# Part 1 shows the convention with SimpleSolvers alone, part 2 with the integrator.

using SimpleSolvers
using GeometricIntegrators
using GeometricProblems: HarmonicOscillator

# --- 1. SimpleSolvers alone: one contraction Φ, the residual in both signs ----------
Φ(x) = 0.5 .* cos.(x)                           # |Φ'| ≤ 0.5, fixed point x* ≈ 0.4502
F_xmΦ!(y, x, params) = (y .= x .- Φ(x))        # F = x - Φ(x)
F_Φmx!(y, x, params) = (y .= Φ(x) .- x)        # F = Φ(x) - x, as ImplicitMidpoint has it

function picard_solve(F!)
    x = zeros(1)
    s = PicardSolver(x, F!, zero(x); max_iterations = 100, verbosity = 0,
        warn_iterations = 0)
    state = NonlinearSolverState(x)
    status = solve_with_status!(x, s, state, nothing)
    (x = x[1], converged = SimpleSolvers.isconverged(status),
        iterations = SimpleSolvers.iteration_number(state))
end

println("SimpleSolvers Picard, F = x - Φ(x): ", picard_solve(F_xmΦ!))
println("SimpleSolvers Picard, F = Φ(x) - x: ", picard_solve(F_Φmx!))

# --- 2. The integrator: one oscillator run, Picard against Newton -------------------
# Both solvers solve the same implicit-midpoint system, so a converged Picard run agrees
# with Newton to the solver tolerance. The stalled one keeps its initial guess instead.
prob = HarmonicOscillator.odeproblem([0.5, 0.0]; timespan = (0.0, 10.0), timestep = 0.1)
q_end = map((Newton(), Picard())) do solver
    int = GeometricIntegrator(prob, ImplicitMidpoint(); solver, verbosity = 0,
        warn_iterations = 0)
    integrate(int).q[end][1]
end
println("ImplicitMidpoint, q(10): Newton ", q_end[1], ", Picard ", q_end[2],
    ", difference ", abs(q_end[2] - q_end[1]))
