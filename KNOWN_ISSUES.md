# Known issues

### K4 · `test/quality/aqua.jl` runs close to the 60 s budget of a `core` file.

- **location:** `test/quality/aqua.jl:7`
- **evidence:** measured after compilation in one process: 44.5 s, 44.9 s, 45.0 s and 54.4 s. A
  run above 60 s moves the file to the `slow` group.
- **kind:** not verified
- **found:** 2026-09-27

### K5 · The documentation and the comments of `src/nonlinear.jl` describe regularization as required, which NonlinearIntegrators 0.5 makes false.

- **location:** `docs/src/findings.md:120`
- **evidence:** `docs/src/findings.md:120-164`, `docs/src/nonlinear_harmonic_oscillator.md:15-16`
  and `:94-103`, `docs/src/nonlinear_pendulum.md:58`, `docs/src/nonlinear_double_pendulum.md:55-59`,
  `docs/src/nonlinear_toda_lattice.md:57-61`, `docs/src/index.md:72-74`, the comment at
  `src/nonlinear.jl:8-10` and the docstring of `nonlinear_regularization_factors` state that a
  nonzero regularization factor is required for the network Newton solve to converge. They were
  measured on NonlinearIntegrators 0.4, whose Newton step is an LU solve. NonlinearIntegrators 0.5
  takes the minimum-norm step of a rank-revealing solve, and `run_nonlinear_case` on the 10-step
  harmonic-oscillator spec converges at λ = 0 (1.8 Newton iterations on average, accuracy
  1.42e-13) as at λ = 1e-5 (2.2 iterations, 1.41e-13). With the same settings the pendulum,
  double-pendulum and Toda-lattice specs converge at λ = 0 and at every rung. The measurement
  `scripts/run_all.jl` and the pages generated from it have to be run again on
  NonlinearIntegrators 0.5.
- **kind:** docs
- **found:** 2026-11-01
