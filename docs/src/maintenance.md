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
- `NonlinearIntegrators` comes from the General registry like every other dependency.
  `docs/Project.toml` still carries a `[sources]` entry, but only the
  `SolverBenchmark = {path = ".."}` one that points the docs at this working tree.

## Documentation

- The analysis pages regenerate their figures at build time inside `@example` blocks,
  with `timing = :quick, quiet = true`. A change to the benchmark therefore changes
  the docs, and a benchmark that errors breaks the build.
- **The build is fanned out over eighteen jobs**, because running all twenty-four sweeps
  in one job takes hours. Every sweep goes through [`cached_sweep`](@ref), keyed by page
  and time step:

  | | |
  |:--|:--|
  | `sweep` matrix job | `DOCS_PAGES=<page>.md julia --project=docs docs/make.jl` with `SOLVERBENCHMARK_SWEEP_CACHE` set. Builds that one page, so only its sweeps run; the rendered output is discarded and the written CSVs are uploaded as an artifact. |
  | `documenter` job | Downloads every artifact into one directory, builds the whole site — now all cache hits — and deploys. |

  Measured on one page: 148 s computing versus 43 s from cache, so the assembling job
  is dominated by the fixed Documenter overhead rather than by the benchmark.
- **`SOLVERBENCHMARK_SWEEPS` splits a page finer than the page**, naming the cache keys a
  job is to compute; the page's other sweeps raise [`SweepNotSelected`](@ref) and are
  skipped. The implicit-midpoint pages take a whole page each (two sweeps), while the
  nonlinear pages get one job per time step — three sweeps of 112 runs apiece, and they
  set the critical path of the workflow, so splitting them is what shortens it.
- Adding a sweep to a page means adding it to the matrix in
  `.github/workflows/Documenter.yml`. A key that no job claims is not an error: the
  `documenter` job computes it itself, which shows as that job taking far longer than its
  usual few minutes and as its `collected N sweeps` count falling short of 24.
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

!!! warning "The documentation is built on macOS with Julia 1.11, and why"
    On Linux with Julia 1.12 (LLVM 18.1.7) the sweeps abort mid-run with a silent
    `SIGABRT`: exit 134, no exception, no stack trace, nothing on stderr even under a pty.
    A core dump named it:

    ```
    llvm::SelectionDAGISel::CannotYetSelect(llvm::SDNode*)
      → llvm::report_fatal_error → abort()
    from JuliaOJIT::addModule ← jl_compile_codeinst_now ← jl_compile_method_internal
    ```

    LLVM's X86 backend cannot select an instruction for a DAG node while the JIT compiles
    a method, so it calls `report_fatal_error`. Because that aborts *inside LLVM*, it never
    becomes a Julia exception — hence the silence. It is an upstream code-generation bug;
    nothing in this repository is implicated, and the same commit passes and fails
    depending only on which runner it draws.

    That is also why it looked so erratic. It hit a different sweep each run, because the
    host's target features and which specialization gets compiled decide, not the
    benchmark. Retrying was useless (the same runner reproduced it at 66 s, then 63 s), and
    it never reproduced on arm64. Failures fell mostly on the newest cores — `znver5`,
    `graniterapids`, `sapphirerapids` — but not exclusively, so the microarchitecture is a
    tendency and the backtrace is the fact.

    Ruled out along the way, each by a test that actually ran: **BLAS threading**
    (`OPENBLAS_NUM_THREADS=1`) and **OpenBLAS kernel dispatch** (`OPENBLAS_CORETYPE`).

    !!! note "`JULIA_CPU_TARGET` cannot be probed by setting it for the run"
        It does not invalidate the pkgimages, so Julia reuses the ones built for the native
        target and nothing is tested — while the attempt reports code generation as
        excluded. The tell is timing: a no-op reaches `ExpandTemplates` half a minute
        later, where a genuine precompile of this stack takes eleven minutes.

    So both jobs run on `macos-latest` with Julia `1.11`: arm64 uses a different LLVM
    backend, and 1.11 predates this LLVM. Revisit once a Julia release carries a fixed
    LLVM — the pin is a workaround for an upstream bug, not a requirement of this package,
    which supports 1.11 upwards and is tested across all three platforms by `CI.yml`.
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
