# Known issues

### K4 · `test/quality/aqua.jl` runs close to the 60 s budget of a `core` file.

- **location:** `test/quality/aqua.jl:7`
- **evidence:** measured after compilation in one process: 44.5 s, 44.9 s, 45.0 s and 54.4 s. A
  run above 60 s moves the file to the `slow` group.
- **kind:** not verified
- **found:** 2026-09-27
