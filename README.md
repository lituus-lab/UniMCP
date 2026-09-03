<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniMCP

A Model Context Protocol server, as a library, for the `lituus-lab` `Uni*`
family. UniMCP owns the part of MCP that is the same in every server — JSON-RPC
framing, the initialization handshake, protocol negotiation, the tool registry,
dispatch and the error codes — and none of what makes a server yours: tools are
your callbacks, and state, authentication and I/O stay on your side.

Three surfaces, one engine: **Nim**, a **C ABI** (two JSON documents and a
function pointer), and a **Python** binding.

**Status: incubating.** The `0.x` C ABI is not frozen. MCP `2025-11-25` and
`2024-11-05` are the negotiated protocol versions; tools are the only
capability advertised.

## Layout

```text
src/UniMCP.nim               umbrella module (re-exports std/json)
src/UniMCP/types.nim         wire shapes: ServerInfo, ToolDescriptor, Server
src/UniMCP/server.nim        lifecycle, dispatch, JSON-RPC errors, stdio
src/UniMCP/c_api.nim         C ABI
include/UniMCP.h             hand-written C header
tests/test_protocol.nim      the session a client walks
tests/test_dispatch.nim      everything a client can get wrong
tests/c/                     C ABI test (links the header against the lib)
examples/                    Nim + C demos
py/                          Cython binding + pytest
book/                        the six-chapter book
ADRs/                        0001 DAG, 0002 license, 0003 engine&shell, 0004 protocol boundary
tools/gate.nim               the failure gate (see "Running a task")
tools/lint.nim tools/vgraph.nim  nimpretty check, layer check
tests/canary_broken.nim      does not compile, on purpose
tests/test_version.nim       the version's six copies must agree
.github/workflows/ci.yml     3-OS Nim matrix + C ABI + Python + all-green
CHANGELOG.md CITATION.cff CODE_OF_CONDUCT.md .editorconfig
```

## Build

```bash
nimble install -y
nim c --hints:off -o:build/unigate tools/gate.nim   # the failure gate, once

build/unigate test    # Nim, debug (contracts active), see below
build/unigate testRelease    # Nim, release (contracts compiled away)
build/unigate testAll        # debug + release + C ABI
build/unigate ctest          # C ABI: static lib + tests/c
build/unigate cexample       # C demo
build/unigate example        # Nim demo
build/unigate pyTest         # Cython + pytest
build/unigate coverage       # gcov + lcov -> coverage/
build/unigate book           # nimib book -> book/__site/
build/unigate docs           # book + API reference -> pages/
build/unigate canary         # must fail: proves the gate still works
```

## Running a task

Nimble 0.22 exits 0 even when an `exec` inside a task failed: the exception is
printed, the task stops, and the process still reports success. `nimble test`
coming back 0 therefore proves only that nimble ran. Every task here ends by
writing its own success marker, and `tools/gate.nim` is what turns a missing
marker into a non-zero exit.

Run tasks through `build/unigate`, never bare, wherever the answer matters.
`build/unigate canary` compiles a source that cannot compile and must come back
non-zero; a CI job checks exactly that, because a gate nobody tests is a gate
nobody can trust.

## CI

`test`, `cabi` and `python` on ubuntu/macOS/Windows. `consume-cabi` and
`consume-wheel` rebuild against the published artifacts on a machine without Nim,
so what ships is what was tested. `coverage` and `docs` run on ubuntu. `canary`
checks that the gate still rejects a broken build.

`all-green` gathers every job's result and is the single check branch protection
requires: a job that was skipped or cancelled cannot pass for one that ran.

`dco` blocks PRs missing a `Signed-off-by` trailer; `commitizen` blocks PRs whose
commits or title are not [Conventional Commits](https://www.conventionalcommits.org/)
(`CONTRIBUTING.md`).

The same gates run locally with pre-commit: `pip install pre-commit && pre-commit install`
(`CONTRIBUTING.md`).

`pages` deploys the built docs, and is opt-in through the `PUBLISH_PAGES`
repository variable. It is off by default: across the family today every one of
these deployments reports success while every site answers 404, and a job that
is red forever teaches everyone to ignore red.

## Using it

```nim
import UniMCP

proc handler(name: string; arguments: JsonNode): JsonNode =
  if name != "shout": raise newException(RpcError, "unknown tool: " & name)
  toolResult(%*{"shouted": arguments["text"].getStr.toUpperAscii})

var server = newServer(
  ServerInfo(name: "demo", title: "Demo", version: "1.0.0",
    description: "One tool, shouted back"),
  latestProtocol = "2025-11-25", supportedProtocols = @["2025-11-25"],
  tools = @[tool("shout", "Shout", "Upper-case a string",
    %*{"type": "object", "properties": {"text": {"type": "string"}},
       "required": ["text"]}, true, false, true, false)],
  handler = handler)

server.serveStdio()   # reads stdin, writes stdout, one message per line
```

The PyPI distribution is `lituus-unimcp`; the import name stays `unimcp`.
Distribution and import are separate decisions, and the bare names are not all
available.

## AI-assisted contributions

Assistance from AI/LLM tools is welcome on the same terms as any other
contribution.

- **Accountability.** The human contributor is the author and remains fully
  responsible for the change. The DCO sign-off (`Signed-off-by`) is the mechanism:
  by signing you certify the content is yours or properly licensed — this covers
  AI-assisted work, provided you can stand behind it.
- **No third-party contamination.** Ensure AI output introduces no code from a
  third party without a compatible license and attribution. If an LLM reproduced
  protected material, do not submit it.
- **Correctness is yours.** The gates (tests, `nimble lint`, conventional commits,
  pre-commit) catch a lot, but you own the result — review and verify what you
  commit.
- **Atomic commits.** Each commit is one logical change. A PR may stack
  several atomic commits (one per element, say) — one monolithic big-bang
  commit is not.
- **Disclosure.** State in the PR whether AI assistance was used (see the PR
  template). It is not a hard requirement — the DCO remains the gate.

## License

Apache-2.0 (`LICENSE`). DCO sign-off on every commit (`CONTRIBUTING.md`).
