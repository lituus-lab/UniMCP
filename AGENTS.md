<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# AGENTS.md — UniMCP

## Build & gates

```bash
nimble install -y
nim c --hints:off -o:build/unigate tools/gate.nim   # the failure gate, once

build/unigate testAll    # Nim debug + release + C ABI
build/unigate pyTest     # Cython + pytest (needs libUniMCP.so)
build/unigate example
build/unigate coverage   # gcov + lcov -> coverage/ (needs lcov; linux/macOS)
build/unigate docs       # nimib book + API reference -> pages/ (needs nimib)
build/unigate canary     # must fail
```

Never `nimble <task>` bare where the answer matters: nimble 0.22 exits 0 even
when an `exec` inside the task failed. The gate reads the task's own success
marker instead, which is the only evidence it ran to its last line.

`nimble docs` needs a complete Nim distribution: `--project` builds `dochack`,
which Homebrew's `nim` omits (no `tools/`). choosenim and the CI action ship it.

CI: Nim, C ABI and Python each on ubuntu/macOS/Windows; lint, docs and
coverage on ubuntu; a canary job that must fail; `all-green` over all of them.

## Conventions

- English comments, terse, describe what is done. No "deprecated".
- No NimContracts here, and the dependency is not declared: every check in this
  library guards the wire protocol or the C ABI, and both must hold under
  `-d:release`, where contracts are compiled away.
- The C ABI never raises: `{.raises: [].}` on every entry point, and a failure
  is a NULL return with the reason in `unimcp_last_error`. `handleLine`'s
  effect is bare `Exception`, because the tool handler is a closure — a
  `CatchableError, Defect` clause does not cover it.
- A protocol error, an ABI failure and a failed tool call are three different
  answers. Only the second is a failure of this library.
- C ABI: hand-written `include/UniMCP.h` kept in sync with
  `src/UniMCP/c_api.nim`; `tests/c` links the header against the lib.
  Built `--app:staticlib`/`--app:lib --noMain --mm:arc -d:release`.
- A change to `c_api.nim` is verified by `ctest`, `pyTest` and, where there
  is one, `wasmTest`: three linkages, three runtime bootstraps. A green
  `ctest` alone proved nothing the day the shared build lost its
  initializer and every registry answered with the sentinel.
- C symbols `unimcp_*` — the library's own name in lower case, not a
  short token: a binary linking several engines holds them in one namespace.
  Lib `libUniMCP`; header `UniMCP.h`.
- `book/*.nim` are nimib chapters: their code blocks are compiled and run at
  docs build, so prose that outlives its API breaks the build. Two of them
  compile and run the C demo and the Python binding, so the book also proves
  the surfaces still work. `py/notebooks/quickstart.ipynb` plays the same role
  for Python and renders natively on GitHub.
- End covered sources with a blank line. Nim maps a trailing statement one line
  past EOF; without that line lcov aborts on `range`/`unmapped`, and `coverage`
  keeps those fatal so the failure stays visible. It ignores exactly one error,
  `mismatch`, which lcov 2.0 raises on a compiler-generated destructor and lcov
  2.5 does not — a generated symbol, not a line of the library.
- `vgraph.cfg` must name the modules that exist. A layer no file answers to
  constrains nothing, and `checkVGraph` then passes on a graph it never read.
- Coverage instruments `tests/test_all.nim` alone: gcov data for a second
  compilation into the same nimcache overwrites the first.

## Scope

A Model Context Protocol server as a library: JSON-RPC framing, the
initialization lifecycle, protocol negotiation, the tool registry, dispatch and
the protocol's error codes. Tools are the caller's callbacks; application
state, authentication and I/O are not this library's business. Tools are the
only MCP capability advertised — see ADR-0005. Apache-2.0, DCO.
