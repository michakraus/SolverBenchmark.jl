# Maintainer notes

The developer documentation for this package lives in the Documenter site, not here. This file is
only an index to it, plus the few rules that are about *how to change the repository*.

## Where things are documented

| Topic | Page |
|:------|:-----|
| What the package does, the code map, driving the integrator by hand, solver options, `quiet`, plot/table conventions | `docs/src/internals.md` |
| The `BFloat16` compatibility layer, the time-grid limit, how `f_abstol_factor` scales | `docs/src/precision.md` |
| Stdlib/docs dependencies, Documenter settings, re-measuring, CI | `docs/src/maintenance.md` |
| The measured results | `docs/src/findings.md` |
| The public API | `docs/src/api.md` |
| Per-problem analyses | `docs/src/{harmonic_oscillator,pendulum,lotka_volterra_2d,lotka_volterra_4d,double_pendulum,toda_lattice}.md`, and `nonlinear_<problem>.md` where one exists |
| User-facing overview | `README.md`, `docs/src/index.md` |

Keep each fact in exactly one of those **pages**. The measured numbers in particular belong only
in `findings.md` — duplicating them invites the copies to drift.

## Working rules

`../CLAUDE.md` loads alongside this file and carries the general rules — never trust a caught
failure, a measured claim needs a measurement, flush `stdout`/`stderr` on long runs.

The pages above are the reference, but they are not loaded into a session. These few are restated
here deliberately, because acting without them is how the mistakes happen:

- **The catching harnesses are `run_case` and `run_nonlinear_case`.** Those are the two to re-run
  with `quiet = false` when a row says "did not converge".
- **The measurement is `scripts/run_all.jl`; the prose to regenerate is `docs/src/findings.md`,**
  from the CSVs rather than by hand.
- After adding a package dependency, re-resolve the **docs** environment too
  (`julia --project=docs -e 'using Pkg; Pkg.resolve()'`) — it does not inherit the root project.
