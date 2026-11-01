# Known issues

### K4 · `test/quality/aqua.jl` runs close to the 60 s budget of a `core` file.

- **location:** `test/quality/aqua.jl:7`
- **evidence:** measured after compilation in one process: 44.5 s, 44.9 s, 45.0 s and 54.4 s. A
  run above 60 s moves the file to the `slow` group.
- **kind:** not verified
- **found:** 2026-09-27

### K5 · The findings and the nonlinear analyses describe regularization as required, which NonlinearIntegrators 0.5 makes false.

- **location:** `docs/src/findings.md:120`
- **evidence:** `docs/src/findings.md:120-164` and `docs/src/nonlinear_pendulum.md:58` (which
  refers to the harmonic-oscillator analysis) state that a nonzero regularization factor is
  required for the network Newton solve to converge. They were measured on NonlinearIntegrators
  0.4, whose Newton step is an LU solve. NonlinearIntegrators 0.5 takes the minimum-norm step of a
  rank-revealing solve, and `run_nonlinear_case` on the 10-step harmonic-oscillator spec converges
  at λ = 0 (1.8 Newton iterations on average, accuracy 1.42e-13) as at λ = 1e-5 (2.2 iterations,
  1.41e-13). The measurement `scripts/run_all.jl` and the pages generated from it have to be run
  again on NonlinearIntegrators 0.5.
- **kind:** docs
- **found:** 2026-11-01
