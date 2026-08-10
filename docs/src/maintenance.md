# Maintenance

Build, dependency and CI notes for this repository.

## Dependencies

- **Stdlib dependencies must be declared explicitly** in `Project.toml` — `Printf`,
  `Markdown` and `Logging` — each with `compat = "1"`. Without the compat entry
  `Pkg.add` pins them to the running Julia's stdlib version, which then conflicts
  with `julia = "1.11"`.
- **After adding or changing a package dependency, re-resolve the docs environment**
  as well:

  ```sh
  julia --project=docs -e 'using Pkg; Pkg.resolve()'
  ```

  It does not inherit the root project.
- `NonlinearIntegrators` is unregistered and comes from its GitHub `main` branch via
  a `[sources]` entry, which requires Julia 1.11 or newer. **The same entry has to be
  repeated in `docs/Project.toml`**, for the same reason.

## Documentation

- The analysis pages regenerate their figures at build time inside `@example` blocks,
  with `timing = :quick, quiet = true`. A change to the benchmark therefore changes
  the docs, and a benchmark that errors breaks the build.
- **The build is fanned out over one job per analysis page**, because running all
  twenty-four sweeps in one job takes hours. Every sweep goes through
  [`cached_sweep`](@ref), keyed by page and time step:

  | | |
  |:--|:--|
  | `sweep` matrix job | `DOCS_PAGES=<page>.md julia --project=docs docs/make.jl` with `SOLVERBENCHMARK_SWEEP_CACHE` set. Builds that one page, so only its sweeps run; the rendered output is discarded and the written CSVs are uploaded as an artifact. |
  | `documenter` job | Downloads every artifact into one directory, builds the whole site — now all cache hits — and deploys. |

  Measured on one page: 148 s computing versus 43 s from cache, so the assembling job
  is dominated by the fixed Documenter overhead rather than by the benchmark.
- **`pagesonly=true` is what makes the split work.** `pages` only builds the
  navigation; without `pagesonly` Documenter expands every `.md` under `docs/src`, and
  each `sweep` job would run the entire study instead of its own page. A page added to
  `docs/src` but not to `PAGES` is silently dropped from the build.
- A partial build passes `warnonly=true`, since cross-references into the omitted pages
  cannot resolve. The `documenter` job builds with warnings fatal, so a broken
  `@ref` still fails there — after every sweep has run, which is what makes it an
  expensive mistake. `docs/make.jl` deploys only when `DEPLOY_DOCS` is `true`, which the
  workflow sets from `needs.sweep.result`, so an incomplete run publishes nothing and
  uploads the site as an artifact instead.
- **The docs are built only by `.github/workflows/Documenter.yml`.** `CI.yml` runs the
  tests; building the docs there too would duplicate hours of compute and race the other
  build for `gh-pages`.
- **Documenter inlines figures as base64**, so several figures per page comfortably
  exceed the default page-size limit. `size_threshold` (and
  `size_threshold_warn`) are raised in the `Documenter.HTML` block of
  `docs/make.jl`.
- A stale figure in a rendered page is worth treating as a symptom: the precision axis
  drops rows it does not recognise silently, so missing bars mean a label mismatch
  rather than a plotting bug. See
  [Plot and table conventions](@ref "Plot and table conventions").

## Re-measuring

```sh
julia --project=. scripts/run_all.jl
```

runs both experiment sets — six implicit-midpoint problems at two time steps and
four nonlinear problems at three — with `BenchmarkTools` timing, writing CSV and
figures to `results/`. It takes hours, and because it measures run times, nothing
else CPU-heavy should run alongside it.

Then update [Key Findings](@ref) from the CSVs, and restate the stack versions and
date at the top of that page. Two standalone studies support it:

- `scripts/f_abstol_study.jl` — the residual-tolerance comparison behind
  [How the residual tolerance scales](@ref "How the residual tolerance scales").
- `scripts/nonlinear_activation_study.jl` — smooth activations against the ReLU
  baseline for the nonlinear integrator.

!!! note "Output is buffered when redirected"
    Julia buffers `stdout` and `stderr` when they are not a terminal, so a long run
    redirected to a file shows nothing until it exits — and a run that is killed
    loses its progress entirely. `scripts/f_abstol_study.jl` flushes explicitly for
    this reason; add the same if you write another long-running script.

## CI

`.github/workflows/CI.yml`:

- **`macOS-latest` runners are arm64** — do *not* force `arch: x64`, which makes
  `setup-julia` error. Leave `arch` unspecified so the runner's native architecture
  is used.
- **Pin the Julia matrix to `'1'`** (latest stable) rather than a specific version;
  naming an unreleased one fails with "Could not find a Julia version that
  matches …".
- **`nightly` is `continue-on-error`.** It fails upstream often enough that it would
  otherwise take the whole workflow down with it.
- Pushes to `main` queue rather than cancel — the concurrency group does not cancel
  in-progress runs. Dependabot Actions-bump PRs auto-merge and occasionally need a
  `git rebase origin/main`.
