# Known issues

### K4 · `test/quality/aqua.jl` runs close to the 60 s budget of a `core` file.

- **location:** `test/quality/aqua.jl:7`
- **evidence:** measured after compilation in one process: 44.5 s, 44.9 s, 45.0 s and 54.4 s. A
  run above 60 s moves the file to the `slow` group.
- **kind:** not verified
- **found:** 2026-09-27

### K6 · The implicit-midpoint pages quote numbers that differ from what the current stack measures.

- **location:** `docs/src/harmonic_oscillator.md:75`
- **evidence:** `scripts/run_all.jl` on GeometricIntegrators 0.18.7 and SimpleSolvers 0.14.3
  measures `BFloat16` on the harmonic oscillator at Δt = 0.1 at 7/24, where
  `docs/src/harmonic_oscillator.md:75` and `docs/src/precision.md:90` say 8/24; the pendulum at
  Δt = 1.0 at 19/24, where `docs/src/pendulum.md:67` says 23/24; and `Picard` at 0 converged rows
  on the pendulum, where `docs/src/pendulum.md:68` says it needs about 8 iterations per step.
  The Lotka–Volterra, double-pendulum and Toda-lattice pages quote counts of the same kind.
  `docs/src/findings.md` carries the current numbers.
- **kind:** docs
- **found:** 2026-11-01

### K7 · `Picard` converges on 1 of 144 implicit-midpoint rows, and the cause is not known.

- **location:** `src/configurations.jl:73`
- **evidence:** `scripts/run_all.jl` on SimpleSolvers 0.14.3: of the 144 `Picard` rows, 57 raise
  `Nonlinear Solver Exception: non-finite direction vector!` or the Hermite identical-times
  `ArgumentError`, and 86 run to the end without meeting the tolerance. Outside the catching
  harness, `_drive!` on `harmonic_oscillator_spec(timespan = (0.0, 100.0), timestep = 0.1)` at
  `Float64` with `Picard` and `NoInitialGuess` raises nothing and returns
  `(converged = false, total_iters = 2048, max_residual = 0.25)`: about two iterations per step,
  far above `f_abstol = 1.8e-15`. The one converged row is `BFloat16` at Δt = 1.0, inside a
  tolerance of `0.0625`. Whether SimpleSolvers' `Picard` or the options that `_solver_options`
  passes to it stops the iteration is not checked.
- **kind:** not verified
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
