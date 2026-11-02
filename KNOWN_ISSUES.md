# Known issues

### K4 · `test/quality/aqua.jl` runs close to the 60 s budget of a `core` file.

- **location:** `test/quality/aqua.jl:7`
- **evidence:** measured after compilation in one process: 44.5 s, 44.9 s, 45.0 s and 54.4 s. A
  run above 60 s moves the file to the `slow` group.
- **kind:** not verified
- **found:** 2026-09-27

### K7 · `Picard` iterates `x ← 2x - Φ(x)` on the implicit-midpoint system, so it cannot converge.

- **location:** `src/nonlinear/picard_solver.jl` of SimpleSolvers 0.14.3 (`direction!` for
  `PicardSolver`) against `src/integrators/implicit_midpoint.jl` of GeometricIntegratorsBase
  0.6.10 (`residual!` for `ImplicitMidpoint`)
- **evidence:** SimpleSolvers' `Picard` steps `x ← x - F(x)`, the fixed-point iteration
  `x ← Φ(x)` for a residual written `F(x) = x - Φ(x)`. `ImplicitMidpoint` hands the solver the
  opposite sign, `F(x) = Φ(x) - x` (`b .= v .- x`, and `(v, f) - x` for the partitioned
  problems), so the step is `x ← 2x - Φ(x)`. On the oscillator at Δt = 0.1, `‖J_Φ‖₂ = 0.05`, so
  `x ← Φ(x)` contracts, while the spectral radius of `2I - J_Φ` is `2.0003`. The residual
  safeguard then halves the step until it underflows and the solve stops on a frozen iterate,
  about two iterations per step. The toggle, in one process: replacing the Picard direction
  `d = -F(x)` by `d = +F(x)` turns `_drive!` with `NoInitialGuess` from
  `(converged = false, total_iters = 2048, max_residual = 0.25)` to
  `(converged = true, total_iters = 9590, max_residual = 1.8e-15)` on the oscillator at
  `Float64`, and makes the oscillator at Δt = 1.0, the pendulum and the Toda lattice converge at
  `Float32` and `Float64`. The Lotka–Volterra `iodeproblem` does not converge either way: its
  residual `ϑ(Q) - p̄ - h f / 2` is not of fixed-point form. The integrator
  `ImplicitMidpointRK()`, the implicit Runge–Kutta form whose residual has the sign `Picard`
  expects, converges on the same case with `total_iters = 9000` and
  `max_residual = 1.525906137556099e-15`, the values of the `Picard` row in the measurement
  before the stack moved. In GeometricIntegrators 0.16.2 the exported name `ImplicitMidpoint` is
  that implicit Runge–Kutta method (`struct ImplicitMidpoint <: IRKMethod`); on the current stack
  it names GeometricIntegratorsBase's own integrator, so the earlier `Picard` rows ran on the other
  residual. Which release made the switch is not checked. Of the 57 `Picard` rows that raise `non-finite direction vector` or
  the Hermite identical-times `ArgumentError`, 24 sit in a precision and initial-guess column
  where no other solver converges either (the time-grid limits of `docs/src/precision.md`);
  the other 33 are not traced one by one.
  `scripts/picard_residual_sign.jl` reproduces both halves without the harness: SimpleSolvers'
  `PicardSolver` on `Φ(x) = cos(x) / 2` converges in 24 iterations with `F = x - Φ(x)` and not
  in 100 with `F = Φ(x) - x`, and `integrate` with `ImplicitMidpoint()` and `Picard()` ends the
  oscillator `2.5e-4` away from `Newton()` at t = 10.
- **kind:** upstream
- **found:** 2026-11-01

### K8 · At `BFloat16` the `ShallowNet` integrator cannot be built.

- **location:** `src/nonlinear.jl:190`
- **evidence:** `nonlinear_onelayer_method(BFloat16)` raises
  `DimensionMismatch: new dimensions (1, 11) must be consistent with array length 10` in
  `NonlinearIntegrators.NetworkIntegratorCore` (`src/nvi/network_integrator_core.jl:28` of
  NonlinearIntegrators 0.5.0), which reshapes `collect(zero(T):(one(T)/10):one(T))` into 11
  columns. In `BFloat16` that range has 10 elements:
  `length(zero(BFloat16):(one(BFloat16)/10):one(BFloat16)) == 10`. Every `BFloat16` row of the
  nonlinear set is therefore recorded as non-converged without a solve.
- **kind:** upstream
- **found:** 2026-11-01

### K9 · The `f_abstol` column is not the tolerance a converged row met, so 60 rows are converged above it.

- **location:** `src/benchmark.jl:140`
- **evidence:** `_drive!` records `SimpleSolvers.isconverged(status)`, and SimpleSolvers accepts
  a step when `rfₐ ≤ f_abstol + f_reltol ‖F(x₀)‖`; `_solver_options` leaves `f_reltol` at its
  default `√eps(T)`. The comment at `src/benchmark.jl:140` says `f_abstol` is recorded "so that
  `max_residual` can be read against the target it was actually solved to", which the relative
  term makes false. `scripts/run_all.jl` on SimpleSolvers 0.14.3 gives 60 converged rows with
  `max_residual > f_abstol`: one implicit-midpoint row (the double pendulum at Δt = 0.1,
  `Float16`, `Newton/BierlaireQuadratic`, `HermiteExtrapolation`, `0.474` against `0.25`) and 59
  nonlinear rows at `Float64` (28 each on the double pendulum and the Toda lattice at Δt = 0.1,
  three on the oscillator at Δt = 0.1 and 10.0; up to `3.1e-10` against `5.7e-14`). Driving two of them step by
  step: the double-pendulum row accepts step 64 at `rfₐ = 0.474` with
  `f_reltol ‖F(x₀)‖ = 2.70` (`x_converged = true`, `f_converged = false`); the Toda-lattice
  LODE row, `DogLeg`, λ = 0, accepts six steps above `f_abstol`, step 3 at `rfₐ = 5.75e-14` with
  `f_reltol ‖F(x₀)‖ = 3.4e-13`. With `f_reltol = 0` both rows report `converged = false`.
  Whether the harness should pass `f_reltol = 0`, which changes the measured counts, or record the
  relative gate beside `f_abstol` is not decided.
- **kind:** defect
- **found:** 2026-11-02

### K10 · A timing run that raises turns a converged row into a non-converged one.

- **location:** `src/benchmark.jl:168`
- **evidence:** `run_case` times the case by driving the same integrator again (`@belapsed` for
  `timing = :benchmark`, one `@elapsed` for `:quick`), inside the `try` of the representative
  run. A repeated `_drive!` is not the same computation: the integrator carries its state over,
  and on `lotka_volterra_2d_spec(timespan = (0.0, 10.0), timestep = 0.01)` at `BFloat16` with
  `Newton/Static` and `NoInitialGuess` three drives in a row give `converged = true` with 1019
  iterations, `converged = true` with 1186, and `SingularException(1)`. `run_case` on that case
  returns `converged = true`, `iterations_mean = 1.019` with `timing = :none` and `:quick`, and
  `converged = false` with every metric `missing` with `:benchmark`. Against the docs-time
  sweeps (`:quick`), the CSVs of `scripts/run_all.jl` (`:benchmark`) disagree on `converged` in
  7 of 1152 implicit-midpoint rows, all of them 16-bit `NoInitialGuess` rows on the
  Lotka–Volterra systems: 2 at Δt = 0.01 and 3 at Δt = 0.1 in 2d, 2 at Δt = 0.01 in 4d; the CSV
  says `false` in each. So the prose of `docs/src/lotka_volterra_2d.md` and
  `docs/src/lotka_volterra_4d.md`, taken from the CSVs, gives lower 16-bit counts than the
  results tables rendered beside it. `run_nonlinear_case` (`src/nonlinear.jl:297`) times the
  same way.
- **kind:** defect
- **found:** 2026-11-02
