<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: UniMCP conventions

- Status: Accepted
- Date: 2026-07-15
- Scope: UniMCP

## Layout

```text
UniMCP.nimble               package + tasks
config.nims                 arch-conditional build flags
src/UniMCP.nim              umbrella; re-exports std/json with the engine
src/UniMCP/types.nim        wire shapes
src/UniMCP/server.nim       lifecycle, dispatch, errors, stdio
src/UniMCP/c_api.nim        C ABI
include/UniMCP.h            hand-written C header
tests/ tests/c/             Nim + C ABI tests
examples/                   Nim + C demos
py/                         Cython binding + pytest
book/                       nimib book, code blocks run at build
ADRs/                       0001-0005
.github/workflows/ci.yml    3-OS Nim + C ABI + Python
LICENSE NOTICE CONTRIBUTING.md SECURITY.md .gitignore README.md AGENTS.md CLAUDE.md
```

## Naming

- Nim package/module: `UniMCP` (PascalCase).
- C library: `libUniMCP`. C header: `UniMCP.h`.
- C symbol prefix: the library's own name in lower case, `unimcp_`. Not a short
  token: a binary that links several engines at once holds them all in one
  namespace, and `um_` has more than one plausible owner.

## Conventions

- English comments, terse, describe what is done. No "deprecated".
- No NimContracts here, and the dependency is not declared. Every check in this
  library guards the wire protocol or the C ABI, and both must hold under
  `-d:release`, where contracts are compiled away — a `require:` there would
  read as a guarantee the release build does not make. The family convention is
  to decide, not to carry the boilerplate unused.
- The C ABI never lets a Nim exception cross: `{.raises: [].}` on every entry
  point, and a failure is a NULL return with the reason in
  `unimcp_last_error`.
- A protocol error and an ABI failure are different answers and reach a caller
  differently. See ADR-0005.
- The umbrella re-exports `std/json`: every public procedure takes or returns a
  `JsonNode`, so `import UniMCP` alone has to be enough to build a request.
- Layers, checked by `nimble checkVGraph`: `types` → `server` → `c_api`, and
  never upward.

## CI gates

Every task runs through `tools/gate.nim`: nimble exits 0 on a task whose `exec`
failed, so its exit code proves nothing and the task's own success marker is
what the gate reads.

- `testCi` + `testCiRelease` on ubuntu/macOS/Windows.
- `ctest`, `cexample` and `clib` on ubuntu/macOS/Windows.
- the Python matrix on ubuntu/macOS/Windows, 3.10 to 3.14.
- `lint`, `checkVGraph`, `docs` and `coverage` on ubuntu.
- `canary`, which must fail.
- `all-green` over all of them: the one check branch protection requires.

A change to `c_api.nim` is verified by `ctest`, `pyTest` and, where there is
one, `wasmTest`: three linkages, three runtime bootstraps.
