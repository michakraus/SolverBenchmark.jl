# Changelog

All notable changes to SolverBenchmark.jl are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`BFloat16` is swept alongside `Float16`.** `default_precisions()` is now
  `(BFloat16, Float16, Float32, Float64)`, so both experiment sets grow by a
  quarter (96 runs per implicit-midpoint problem, 64 per nonlinear problem). The
  two 16-bit formats divide their bits differently — `Float16` has 11 significand
  bits and a 5-bit exponent, `BFloat16` 8 and 8 — so sweeping both separates a
  failure caused by too few digits from one caused by too little dynamic range.
  `BFloat16` is re-exported, so callers need no direct BFloat16s dependency.
- `precision_label(T)`, the name written to the `precision` column. It uses
  `nameof` rather than `string`, which renders a type module-qualified when its
  module is not visible from `Main` — `string(BFloat16)` gives
  `"BFloat16s.BFloat16"` inside a Documenter `@example` sandbox, and the plotting
  code drops rows whose precision label it does not recognise.
- `scripts/f_abstol_study.jl`, comparing the relaxed `f_abstol_factor = 256`
  against the framework default for the specs that override it. Its study is the
  function `run_abstol_study(; resultsdir)`, so the output directory is a keyword
  like the shared runners' rather than a load-time constant. Running the script
  still writes `results/f_abstol_study.md`; an `include` defines the function and
  runs nothing, so a caller can pass `resultsdir` before any output is written.
- `RegularizationConfig`, `scaled_regularization` and `regularization_exponent`:
  the nonlinear sweep's `regularization_factor` is now a function of the working
  precision rather than a number. Nonlinear rows carry the exponent and the value
  each one resolved to in `regularization_exponent`/`regularization_factor`.
- `cached_sweep`/`sweep_cache_dir`/`selected_sweeps`/`SweepNotSelected`, and a
  `DOCS_PAGES` knob on `docs/make.jl`: the
  documentation build now fans out over one CI job per analysis page, each computing
  only that page's sweeps and passing the results to the job that renders the site.
  Without a cache directory configured it is a plain call, so a local
  `julia --project=docs docs/make.jl` behaves exactly as before.
- `_REGULARIZATION_ORDER` and `_PANEL_ORDER` in `src/plots.jl`, so the nonlinear
  panels have an explicit display order instead of relying on `λ` being the
  innermost loop. `_PANEL_ORDER` covers both experiment sets, so no call site has to
  name the order it wants.

### Changed

- **The documentation is built on arm64 Linux, and `Documenter` is a required check.** Both
  jobs of `Documenter.yml` run on `ubuntu-24.04-arm` instead of `macos-latest`. arm64 still
  avoids the Julia 1.12 `SIGABRT` in LLVM's X86 backend, and the Linux runners are not held to
  the account's limit of five macOS jobs at a time, which stretched a run to 2 h 48 min, with
  sweeps waiting up to 2 h 17 min to start, where the longest sweep took 33 min. A pull request now cannot merge with broken docs: the
  `Documenter` job fails whenever a sweep failed, and the ruleset `docs` requires it.
- **The implicit-midpoint pages are measured again on the current stack (removes
  `KNOWN_ISSUES.md` K6), and K7 names why `Picard` fails.** `scripts/run_all.jl` on
  GeometricIntegrators 0.18.7, GeometricIntegratorsBase 0.6.10 and SimpleSolvers 0.14.3
  reproduces the counts of Key Findings; the pages follow it. `Picard` converges nowhere, so
  the pages no longer describe its iteration counts: SimpleSolvers' `Picard` steps
  `x ← x - F(x)` while `ImplicitMidpoint` hands it `F(x) = Φ(x) - x`, which makes the step
  `x ← 2x - Φ(x)` (K7, now kind `upstream`, reproduced by `scripts/picard_residual_sign.jl`).
  At `Float32`/`Float64` every other configuration converges on the oscillator, the pendulum and
  the Toda lattice (21/24 each, from 24/24 on the first two). `Float16` loses
  `MidpointExtrapolation` on every fine-step sweep, because ``t - \Delta t/2`` rounds onto the
  previous grid time from ``t = 64.2`` on `0:0.1:100` and from ``t = 8.01`` on `0:0.01:10`: the
  oscillator goes to 14/24 (from 24/24), the pendulum to 13/24 (from 24/24), the Toda lattice to
  14/24 (from 21/24); `docs/src/precision.md` documents the collision. `BFloat16` on the
  oscillator is 7/24 and 22/24 (from 8/24 and 24/24), on the pendulum at Δt = 1.0 19/24 (from
  23/24). Lotka–Volterra 2d `Float16` is 7/24 at both steps (from 9/24 and 13/24) and `BFloat16`
  2/24 at Δt = 0.1 (from 7/24); 4d `Float16` 11/24 and 4/24 (from 14/24 and 6/24) and
  `BFloat16` 4/24 at Δt = 0.1 (from 6/24). The double pendulum at Δt = 0.01 converges 46/96
  (from 58/96) and 54/96 at Δt = 0.1 (from 64/96), and its residual-floor table in
  `docs/src/precision.md` is measured again (≈ 200 … 256 ε(T), from ≈ 150 … 260). The
  `16√eps(T)` entry of the `BFloat16` ladder in `docs/src/precision.md` is marked on rung 4,
  where it is, instead of rung 3. The comparison of `f_abstol_factor = 8` against `256`
  (`scripts/f_abstol_study.jl`) is not run again.
- **Key Findings and the nonlinear pages are measured again, on `NonlinearIntegrators` 0.5, and
  no longer describe regularization as required (closes `KNOWN_ISSUES.md` K5).**
  `NonlinearIntegrators` 0.5 takes the minimum-norm step of a rank-revealing Newton solve, so at
  `Float64` λ = 0 converges for all four solvers wherever the rungs do, except one marginal row
  (the oscillator at Δt = 10.0, `Newton/Static`, rung 1): λ = 0 converges on 24 of 192 rows
  (from 8 of 176) against 24–29 per rung (from 23–31). The `Float64` Toda lattice converges 28/28 in 2.6–3.0 iterations per step (from
  24/28, none at λ = 0, about 12), the double pendulum 28/28 with `Newton/Static` included (from
  19/28), and the pendulum 28/28 (from 24/28). `Float32` converges on 40 of 336 nonlinear rows
  (from 54 of 308), `Float64` on 141 of 336 (from 116 of 308). At `BFloat16` the integrator is no
  longer buildable (K8), so the 16-bit rows fail before the solve for two different reasons.
  The implicit-midpoint numbers of Key Findings move with the stack as well: `Picard` converges
  on 1 of 144 rows (from 44, K7), `Float64` on 248 of 288 (from 263), and the robust solvers
  take about 1.4 iterations per step (from 1.34). `docs/src/index.md`, the comment above the
  nonlinear set in `src/nonlinear.jl` and the docstring of `nonlinear_regularization_factors`
  follow. K6 records the implicit-midpoint pages that still quote the earlier numbers.
- **The bounds move to `NonlinearIntegrators` 0.5 and the `GeometricBase` 0.15 releases it builds
  on.** `NonlinearIntegrators = "0.5"` (from `"0.4.1"`): every 0.4 release requires
  `GeometricBase` 0.14, so it could not install beside the other floors below.
  `GeometricIntegrators = "0.18.6"` (from `"0.18.4"`), `GeometricIntegratorsBase = "0.6.9"` (from
  `"0.6.4"`), `GeometricProblems = "0.9.1"` (from `"0.8, 0.9"`) and `QuadratureRules = "0.2.2"` (from
  `"0.2"`) are the first releases on `GeometricBase` 0.15; `SimpleSolvers = "0.14.2"` (from
  `"0.13, 0.14"`) is the floor that `NonlinearIntegrators` 0.5 requires. The Julia floor stays
  1.12. Nothing in the code changes. `NonlinearIntegrators` 0.5 solves the near-singular network
  Newton system with a rank-revealing linear solve, so the nonlinear runs converge at λ = 0 as at
  λ > 0: the test that asserted the λ = 0 run stalls now asserts that it converges, and the
  documentation is measured again on 0.5 (see the entry above). These bounds replace those of the
  entry on the four lower bounds below.
- **CI uploads coverage from the `Julia 1 - ubuntu-latest` job instead of `Julia min`, and a test
  job saves the Julia cache only when it succeeds.**
- **`test/Project.toml` and `docs/Project.toml` carry no `[compat]` entry for a dependency of the
  root `Project.toml`.** Both environments contain the package, so the resolver applies the root's
  bounds to every shared dependency, and an entry there can only narrow them. Removed:
  `DataFrames` from `test/Project.toml`; `CairoMakie`, `DataFrames`, `GeometricProblems`,
  `NonlinearIntegrators` and `PrettyTables` from `docs/Project.toml`. The test-only and docs-only
  bounds (`Aqua`, `SafeTestsets`, `Documenter`) stay.
- **Four lower bounds are raised to versions that can install.** On Julia 1.12, with each other
  entry as written, the old floors do not resolve:

  | entry | was | is | why the old floor fails |
  |:--|:--|:--|:--|
  | `GeometricIntegrators` | `0.18` | `0.18.4` | 0.18.0 needs `SimpleSolvers` 0.10 and 0.18.1–0.18.3 at most 0.12, below this package's `0.13, 0.14` |
  | `GeometricIntegratorsBase` | `0.6` | `0.6.4` | 0.6.0–0.6.3 need `SimpleSolvers` 0.11–0.12 |
  | `NaNMath` | `1` | `1.1.2` | `SymbolicUtils` 4, which `Symbolics` 7 needs, admits `NaNMath` only from 1.1.2 |
  | `NonlinearIntegrators` | `0.4` | `0.4.1` | 0.4.0 needs `SimpleSolvers` 0.12 |

  The new floor is in each case the lowest registered version that resolves. All floors together
  resolve on 1.12.7. Nothing any user installs changes: the resolver never chose these versions,
  because it could not. The `Downgrade` job in `CI.yml`, new with this change, runs the suite at
  exactly these floors.
- **The test suite follows the shared layout.** The single `test/runtests.jl` is split into
  `configurations.jl`, `benchmark.jl`, `problems.jl`, `nonlinear.jl` and `cache.jl`, each run in
  its own `@safetestset` under the `core` group; the 281 assertions are unchanged. The test
  dependencies move from `[extras]`/`[targets]` to `test/Project.toml`, which adds `SafeTestsets`
  and `Aqua`, and lists `DataFrames` with the root's bound. The new `test/quality/aqua.jl` runs `Aqua.test_all`; its piracy check is marked
  broken, because the `BFloat16` shims in `src/bfloat16.jl` are deliberate piracy.
- **The Julia floor is 1.12, raised from 1.11.** Julia 1.11.9 cannot compile this package's
  `BFloat16` broadcasts: the `Julia min` job died with `LLVM ERROR: Cannot select: v16bf16 =
  X86ISD::VFPROUND` and signal 6, which is a codegen failure in the compiler rather than anything
  in this source. `main` had been red that way on every run since 2026-09-07. Because the `min`
  alias resolves the lower bound of this entry, raising the floor is what moves that job onto a
  Julia that can lower the instruction. **No measured number changes** — the sweep never ran on
  the affected job, and nothing else about the package moves.

- **`.gitignore` gains root-anchored `/runs` and `/results`, and `CLAUDE.md` no longer claims
  compliance it did not have.** The rule was `results/` — unanchored, and with no `runs` entry at
  all — where `Packages/CLAUDE.md` requires a root-anchored `/runs` and `/results` in `.gitignore`
  for both output directories. `CLAUDE.md` separately asserted "`results/` is gitignored", which
  read as compliance and is what kept the gap invisible; that line is gone, since the parent file
  owns the rule. Nothing was tracked under either directory, so no history changed. Note that no
  driver currently writes to `runs/` — CSVs and figures both land in `results/` — so the `/runs`
  entry is required by the house split rather than by anything the scripts do today.
- **`CLAUDE.md`'s documentation index no longer implies a nonlinear page for every problem, and
  covers the one page it had missed.** The per-problem row named the six problem pages — all of
  which exist — and then "the `nonlinear_*.md` **counterparts**". That glob matched exactly the four
  pages that do exist (`double_pendulum`, `harmonic_oscillator`, `pendulum`, `toda_lattice`), so no
  row ever named a missing file; what was wrong is that "counterparts" reads as one per problem, and
  `lotka_volterra_2d`/`4d` have none. The row now says `nonlinear_<problem>.md` where one exists,
  which states the actual relation. The six problem pages stay enumerated, because that list is the
  only place a session sees the problem set without listing `docs/src/`. Separately `docs/src/api.md`
  had no row at all, which left the index incomplete rather than duplicated; it has one now. Also
  drops the paragraph narrating which rules "used to be restated here", which described the file's
  own edit history rather than anything to do.
- **The restated rules are now labelled as restatements, not as local facts.** The working-rules
  bullets said they were "what is local to this repository", but all three are also in the
  Documenter pages this file indexes — the docs-environment one verbatim at
  `docs/src/maintenance.md`. They stay, because `CLAUDE.md` is loaded into every session and the
  docs site is not; the preamble now says that is deliberate. The index rule above it is scoped to
  "those **pages**", so it no longer reads as a rule this file immediately breaks. This corrects the
  entry below, which called these three bullets the part that is "local to this repository": the
  harnesses and `quiet = false` are at `docs/src/internals.md:63,74`, the `run_all.jl` regeneration
  at `docs/src/maintenance.md:109-120`, and the docs re-resolve verbatim at
  `docs/src/maintenance.md:11-18`. Nothing about the rules changed, only the claim that they were
  unique to this file.
- **`CLAUDE.md`'s opening drops the changelog rule it shared with the tree.** "Describe the package
  as it is in the docs; put anything about how it got that way in the changelog" is stated by
  `~/.claude/CLAUDE.md` under *Every repository carries a `CHANGELOG.md`*, which this file inherits.
- **`CLAUDE.md` stops restating three rules it shares with `Experiments/CLAUDE.md`.** *Never trust
  a caught failure*, *a measured claim needs a measurement* and flushing `stdout`/`stderr` on long
  runs were held near-verbatim in both files, which load together — inside a file whose own
  opening paragraph says to keep each fact in exactly one place. Only what is local to this
  repository remains: that the exception-catching harnesses are `run_case` and
  `run_nonlinear_case`, and that the measurement is `scripts/run_all.jl` regenerating
  `docs/src/findings.md` from the CSVs. Found by the harness-wide documentation audit of
  2026-09-02; no rule changed, only where it is written.
- **Every dependency moves to its latest registered version, and five of the bumps
  are breaking**: `GeometricIntegrators` 0.17 → 0.18, `GeometricIntegratorsBase`
  0.5.1 → 0.6, `NonlinearIntegrators` 0.2 → 0.4, `QuadratureRules` 0.1 → 0.2 and
  `SimpleSolvers` 0.10.1 → 0.13. `CSV` (0.10.17) and `PrettyTables` (3.4) move
  within their series; `BFloat16s`, `BenchmarkTools`, `CairoMakie`, `DataFrames`,
  `GeometricProblems` and `NaNMath` already admitted their latest and are unchanged.
  `Documenter` goes to 1.18 in `docs/Project.toml`.

  The `SimpleSolvers` and `NonlinearIntegrators` bumps are one constraint, not two:
  `NonlinearIntegrators` 0.3 pins `SimpleSolvers` 0.12 and 0.4.3 pins 0.13.2, so
  there is no intermediate step either could take alone.

- **`NonlinearIntegrators` is resolved from the General registry, not from GitHub
  `main`.** It is registered now, under the same UUID, so the `[sources]` entry in
  `Project.toml` and its duplicate in `docs/Project.toml` are both gone. Julia 1.11
  remains the floor, but for a different reason — `NonlinearIntegrators` 0.4 declares
  `julia = "1.11"` itself, where previously it was `[sources]` that required 1.11+.
  `docs/Project.toml` keeps only the `SolverBenchmark = {path = ".."}` source.

- **The one-layer network integrator is renamed throughout**, following
  NonlinearIntegrators 0.3.0's rename of its whole exported surface:
  `NonLinear_OneLayer_GML` → `ShallowNet`, `OneLayerNetwork_GML` →
  `ShallowNetBasis`, and the seed `OGA1d_Legacy` → `OGA1dNormalEquations`. Only
  `nonlinear_onelayer_method` and `scripts/nonlinear_activation_study.jl` construct
  these, so the code change is three names; the rest is comments and docs that named
  a type which no longer exists. Nothing about the method or its default seed
  changes — `OGA1dNormalEquations` *is* the old `OGA1d_Legacy`, renamed upstream to
  say what it is (the reference normal-equations fit in a `Float64` island) rather
  than that it came first.

  Without this the sweep does not run at all: the default seed is evaluated as a
  keyword default, so the failure was an `UndefVarError` at construction, outside
  the handler that would otherwise have recorded it as a non-converged row.

- **The measured numbers in `docs/src/findings.md` have not been re-measured against
  this stack.** The test suite passes 281/281 and the documentation builds, so every
  `@example` re-executes and the generated tables and figures on the analysis pages
  are current. The prose figures in `findings.md` come from `scripts/run_all.jl` at
  `timing = :benchmark`, which was not re-run. `SimpleSolvers` moved three minor
  versions and the network integrator was rewritten upstream, so those figures should
  be treated as pre-upgrade until that sweep is repeated.

- **The nonlinear sweep's regularization is scaled to the precision.** It ran
  `λ ∈ {0, 1e-3, 1e-5, 1e-7}`; all three nonzero values are far below `√eps(T)` at
  anything but `Float64`, so they could not lift a near-singular Jacobian in reduced
  precision and the sweep could not distinguish "λ too small" from "precision too
  low". It now runs the `λ = 0` control plus six rungs of `2^k √eps(T)` —
  `k = 1…6` at `BFloat16`/`Float16`/`Float32`, `k = 2, 4, …, 12` at `Float64`, both
  ladders containing NonlinearIntegrators' recommended `16√eps(T)`. 112 runs per
  nonlinear problem, up from 64. Panels are labelled by rung, because the value
  behind a rung differs by precision while a `DataFrame` holds all four.
  Measured, this removes the confound without changing the verdict: the
  reduced-precision runs fail in the OGA initial guess, not in the Newton solve
  `regularization_factor` acts on — see `docs/src/findings.md`.

- **The Toda lattice uses the framework's default residual tolerance again.** Its
  `f_abstol_factor = 256` was re-measured against the alternative: it bought 3
  converged runs of 96 at `Δt = 0.1` and 1 at `Δt = 1.0`, while costing one to two
  orders of magnitude of residual on every run that converged either way (`Float64`
  worst case `1.8e-15` → `5.7e-14`). Unlike the double pendulum, the Toda lattice
  has no raised residual floor. The double pendulum and the four LODE specs keep
  their overrides, which the same measurement shows are still load-bearing.
- **The documentation is built by one workflow, not two.** `CI.yml` no longer carries a
  `Documentation` job: it duplicated the whole build and raced
  `.github/workflows/Documenter.yml` for the `gh-pages` branch. That workflow now runs a
  `sweep` matrix of eighteen jobs — a whole page for each implicit-midpoint problem, and
  one job per time step for the nonlinear pages, whose three sweeps of 112 runs set the
  critical path — followed by a `documenter` job
  that collects their results, renders the site and deploys, and withholds the
  deployment when any sweep failed. `makedocs` is called with `pagesonly=true`, without
  which each `sweep` job would expand every page and run the entire study.
- **The documentation is built on macOS with Julia 1.11.** On Linux with Julia 1.12
  (LLVM 18.1.7) the sweeps abort mid-run with a silent `SIGABRT`; a core dump identified
  `llvm::SelectionDAGISel::CannotYetSelect` — LLVM's X86 backend failing to select an
  instruction while the JIT compiles a method, calling `report_fatal_error` and so
  `abort()`. Aborting inside LLVM is why it never became a Julia exception and produced no
  error at all. It is an upstream code-generation bug: the same commit passed or failed
  depending only on which runner it drew, and BLAS threading and OpenBLAS kernel dispatch
  were both tested and exonerated. arm64 has never reproduced it, and 1.11 predates that
  LLVM. The pin is a workaround, to be lifted when a Julia release carries a fixed LLVM;
  `CI.yml` continues to test the package on 1.11, 1 and nightly across all three
  platforms.
- Benchmark rows carry the `f_abstol` each run was solved to, and `summary_table`
  adds an `at_tolerance` column marking converged rows whose `max_residual` is
  within a factor of ten of it — so "converged against a target too loose to be
  informative" travels with the data. The column is omitted when no row is flagged.
  It is what makes the `BFloat16` double pendulum legible: residual 1.2–1.5 against
  `256 eps(BFloat16) = 2.0`, on a system whose energy is `O(1)`.
- `run_nonlinear_benchmark` builds the integrator once per precision *inside* an
  error handler. A precision whose network cannot be constructed is now recorded
  as non-converged rows instead of aborting the whole sweep.
- `plot_convergence` scales its figure height with the number of precisions
  instead of hard-coding one that fitted three rows.

### Fixed

- **The package precompiles again with BFloat16s 0.6.3, which defines `fma` for `BFloat16`.**
  The local `Base.fma(::BFloat16, ::BFloat16, ::BFloat16)` shim overwrote that method, and
  precompilation refuses an overwritten method, so every test job failed in Aqua's
  persistent-task check. The shim is gone and the BFloat16s floor is `0.6.3`, the first release
  with the method; 0.5.1, 0.6.1 and 0.6.2 have no `fma` method for `BFloat16`.
- **The documentation builds again: it runs on macOS with Julia 1.12, not 1.11.** Raising the
  Julia floor to 1.12 left `Documenter.yml` pinned below it, so every `sweep` job failed at
  `Pkg.develop` with *"julia version requirement from Project.toml's compat section not
  satisfied"* and nothing was deployed. The pin now equals the floor. The job stays on
  `macos-latest`, which is arm64: the Julia 1.12 `SIGABRT` described under *Changed* is in LLVM's
  X86 backend and has never reproduced on arm64.
- **The maintenance page no longer names `julia = "1.11"` as the floor.** Its note on stdlib
  `[compat]` entries now refers to the `julia` floor in `[compat]`, which is `1.12`, so the note
  stays true when the floor moves again.
- **The `at_tolerance` testset no longer asserts a boundary it cannot hold.** It
  required every solver configuration to converge on the double pendulum at
  `f_abstol_factor = 256`, where the residual floor is ≈250 eps(T) against a target of
  256 eps(T) — a margin of 2.4%. `converged` is an AND over all 100 steps, so one step a
  few percent over sinks the row, and the outcome is decided by the last bits of the
  arithmetic: perturbing one initial coordinate by a single ulp moves the residual
  anywhere in 0.78…1.51× the target. `Newton/Static` is the configuration that flips,
  having no line search to pull that step back. The assertion is now
  `all(st.at_tolerance[st.converged])` — every run that converged landed *at* the
  target, which is what the flag reports, and those sit ≈9.8× above the
  `f_abstol / 10` threshold at these conditions.

  **No measured number changes**, and no solver, problem or tolerance changes; this is
  the test's assertion only. The `f_abstol_factor = 256` choice and its justification at
  `src/problems.jl` are untouched — note that the thin upper margin is not mentioned
  there.

- **A `BFloat16` compatibility layer** (`src/bfloat16.jl`). The stack does not
  support `BFloat16` out of the box, and because `run_case`/`run_nonlinear_case`
  record any exception as a non-converged row, each gap first presented as a
  numerical failure rather than a missing method. All are upstream gaps, all use
  the same exact widen-to-`Float32`-and-round, and all should be dropped as
  BFloat16s and NaNMath grow the methods:
  - `Base.rem` and `Base.Integer`, needed by the generic `AbstractFloat` range
    constructor that builds every solution's `TimeSeries`. Without them every run
    fails.
  - `Base.sincos`, which otherwise **recurses until the stack overflows**:
    `sincos(x) = _sincos(float(x))` and `_sincos(x::AbstractFloat) = sincos(x)`.
  - `Base.atan(y, x)`, `Base.fma` and `Base.mod2pi`.
  - `NaNMath.{sin,cos,tan,asin,acos,atanh,acosh,log,log2,log10,log1p}`, whose
    NaN-returning variants are declared for `Union{Float16,Float32,Float64}` only
    while GeometricProblems writes its right-hand sides against them. Adds a direct
    `NaNMath` dependency.

  With the layer in place all six implicit-midpoint problems converge at
  `BFloat16`; without the NaNMath part, four of them appeared not to.

## [0.2.0] — 2026-08-08

Upgrade to the current Geometric* stack.

### Changed

- **Dependencies**: GeometricIntegrators 0.17, GeometricIntegratorsBase 0.5.1,
  SimpleSolvers 0.10.1, GeometricProblems 0.8 (which pulls EulerLagrange 0.5).
  Requires NonlinearIntegrators 0.2.
- **`quiet = true` filters instead of muffling.** It installs a logger that drops
  records from GeometricIntegratorsBase and SimpleSolvers, rather than wrapping each
  run in a `NullLogger`. `verbosity = 0` now silences the benchmarked solver on its
  own; what remains unreachable is `HermiteExtrapolation`'s "history identical"
  warning and the inner `integrate(tem_ode, ImplicitMidpoint())` that
  `NonLinear_OneLayer_GML` runs per step with no options. Warnings from anywhere
  else now reach documentation builds.
- **`_solver_options` states only what it overrides.** GeometricIntegratorsBase 0.5
  merges options over `default_options(method, problem)` instead of replacing them,
  so `min_iterations = 1` no longer needs restating. The framework `f_abstol`
  default is now `max(8, solversize(method, problem)) * eps(T)`; it evaluates to
  `8 eps(T)` for every problem benchmarked here, so no `f_abstol_factor` changed.
- Maintainer notes moved from `memory.md` to `CLAUDE.md`, and the historical
  material in them became this changelog. Comments and documentation now describe
  the package as it is; how it got there is recorded here.

### Fixed

- The documentation index listed four implicit-midpoint analyses; the site builds
  six. Double Pendulum and Toda Lattice were missing.
- The index claimed every problem is integrated over `(0, 100)` at `Δt = 0.1`;
  Lotka–Volterra and the double pendulum use `(0, 10)` at `Δt = 0.01`, and every
  problem also runs at a ten times coarser step.
- Maintainer notes referred to a `_typed_parameters` helper that no longer exists,
  to `scripts/analysis.jl` (since split into `midpoint_analysis.jl` and
  `nonlinear_analysis.jl`), and to `julia = "1.10"` where the project requires 1.11.
  `scripts/nonlinear_analysis.jl` carried the same stale filename.
- `src/nonlinear.jl` described the network integrator as seeding with `OGA1d`; the
  harness default is `OGA1d_Legacy`.

## [0.1.0] — 2026-07-14

Initial benchmark harness.

### Added

- Problem-/integrator-agnostic harness: `ProblemSpec`, `SolverConfig`,
  `InitialGuessConfig`, and `run_case`/`run_benchmark` returning a `DataFrame` of
  convergence, iterations per step, runtime, residual, energy drift and accuracy.
  Because `integrate` does not return solver statistics, runs are driven one step at
  a time so `SimpleSolvers.iteration_number`/`residuals` can be read per step.
- Sweep of precision (`Float16`/`Float32`/`Float64`) × solver (`Newton` with the
  `Static`, `Backtracking`, `Bisection`, `Quadratic`, `BierlaireQuadratic` and
  `StrongWolfe` line searches, plus `DogLeg` and `Picard`) × initial guess
  (`HermiteExtrapolation`, `MidpointExtrapolation`, `NoInitialGuess`) — 72 runs per
  problem, each also at a ten times coarser time step.
- Examples: harmonic oscillator and pendulum (`odeproblem`), Lotka–Volterra 2d and
  4d (`iodeproblem`), double pendulum and Toda lattice with `N = 16` (`hodeproblem`).
- Second experiment set: the neural-network variational integrator
  `NonLinear_OneLayer_GML` from NonlinearIntegrators.jl, sweeping the solver's
  `regularization_factor` `λ ∈ {0, 1e-3, 1e-5, 1e-7}` in place of the initial guess,
  over LODE forms of the oscillator, pendulum, double pendulum and Toda lattice at
  `Δt = 0.1`, `1.0` and `10.0`.
- `relu_k`/`gelu`/`elu` activation factories and configurable `activation` /
  `initial_guess_method` on `nonlinear_onelayer_method`, with the standalone
  `scripts/nonlinear_activation_study.jl` comparing activations against the ReLU
  baseline under both OGA seeds.
- CairoMakie plot helpers (`plot_convergence`, `plot_iterations`, `plot_runtime`,
  `plot_energy_drift`, `plot_accuracy`, `comparison_figure`) and `summary_table` /
  `markdown_table`.
- Driver scripts per example plus `run_all.jl`, writing CSV and figures to a
  gitignored `results/` with the time step encoded in each file name.
- Documenter site regenerating every table and figure at build time, and a test
  suite covering the ODE, IODE, HODE and network-integrator paths.

### Changed

- `f_abstol_factor` on `ProblemSpec`, set to 256 for the double pendulum, the Toda
  lattice and the LODE specs, whose residual floors sit well above `8 eps(T)`.
- `max_iterations` capped at 100 for the implicit-midpoint sweep so divergent
  configurations give up quickly.
- Plot and table ordering of the initial guesses fixed to
  `NoInitialGuess` → `HermiteExtrapolation` → `MidpointExtrapolation`, independent of
  the benchmark's row order.
- Implicit-midpoint driver scripts prefixed `midpoint_`, and `run_all.jl` extended to
  cover both experiment sets.

### Fixed

- CI matrix uses the runners' native macOS arch and released Julia versions.
