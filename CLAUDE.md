# Maintainer notes

The developer documentation for this package lives in the Documenter site, not here.
This file is only an index to it, plus the few working rules that are about *how to
change the repository* rather than about the package itself.

The release history lives in `CHANGELOG.md`. Describe the package as it is in the
docs; put anything about how it got that way in the changelog.

## Where things are documented

| Topic | Page |
|:------|:-----|
| What the package does, the code map, driving the integrator by hand, solver options, `quiet`, plot/table conventions | `docs/src/internals.md` |
| The `BFloat16` compatibility layer, the time-grid limit, how `f_abstol_factor` scales | `docs/src/precision.md` |
| Stdlib/docs dependencies, Documenter settings, re-measuring, CI | `docs/src/maintenance.md` |
| The measured results | `docs/src/findings.md` |
| Per-problem analyses | `docs/src/{harmonic_oscillator,pendulum,lotka_volterra_2d,lotka_volterra_4d,double_pendulum,toda_lattice}.md` and the `nonlinear_*.md` counterparts |
| User-facing overview | `README.md`, `docs/src/index.md` |

Keep each fact in exactly one of those places. The measured numbers in particular
belong only in `findings.md` — duplicating them anywhere invites the copies to drift.

## Working rules

Three of the rules that used to be restated here are in `../CLAUDE.md`, which loads alongside
this file — *never trust a caught failure*, *a measured claim needs a measurement*, and flushing
`stdout`/`stderr` on long runs. Read them there. What is local to this repository is only where
they bite:

- **The catching harnesses are `run_case` and `run_nonlinear_case`.** Those are the two to
  re-run with `quiet = false` when a row says "did not converge".
- **The measurement is `scripts/run_all.jl`; the prose to regenerate is
  `docs/src/findings.md`,** from the CSVs rather than by hand.
- **`results/` is gitignored.** Figures and CSVs are build products; the docs regenerate their
  own figures at build time.
- After adding a package dependency, re-resolve the **docs** environment too
  (`julia --project=docs -e 'using Pkg; Pkg.resolve()'`) — it does not inherit the
  root project.
