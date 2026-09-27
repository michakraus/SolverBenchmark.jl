# Known issues

## KI-1 — docs: issue #29 miscounts the pirated methods

Issue #29 says Aqua's piracy check fails on 18 methods. Aqua reports 17: 6 in `Base` and 11 in
`NaNMath`, all from `src/bfloat16.jl`. Evidence: the `Piracy` test summary of
`test/quality/aqua.jl`. The fix is to change "18" to "17" in the issue body.

## KI-2 — docs: `test/benchmark.jl` keeps the suite-wide header comment

The header comment of `test/benchmark.jl` still describes the whole suite ("so the suite exercises
every code path …"). It came from the old single `test/runtests.jl`. The fix is to reword it for
this one file.

## KI-3 — docs: the CHANGELOG entry for the test layout omits DataFrames

The `[Unreleased]` entry names `SafeTestsets` and `Aqua` as new in `test/Project.toml`, but
DataFrames is also new there. Evidence: `test/Project.toml` compared with the removed
`[extras]` (which held only `Test`).

## KI-4 — performance: `test/quality/aqua.jl` is close to the 60 s `core` budget

Measured after compilation in one process: 44.5 s, 44.9 s, 45.0 s and 54.4 s. If a run goes above
60 s, the file moves to the `slow` group.
