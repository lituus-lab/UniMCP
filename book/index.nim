# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "UniMCP"

nbText: """
# UniMCP

A Model Context Protocol server, as a library. UniMCP owns the part of MCP that
is the same in every server — JSON-RPC framing, the initialization handshake,
protocol negotiation, the tool registry, dispatch, and the error codes — and
owns none of what makes a server yours. Tools are your callbacks; state,
authentication and I/O stay on your side of the boundary.

It ships across the three surfaces every `lituus-lab` engine ships: **Nim**, a
**C ABI**, and a **Python** binding. All three drive the same engine, and the
last two chapters show where they differ.

**Read this front to back.** Each chapter uses what the one before it
introduced.

## Installing

```bash
nimble install https://github.com/lituus-lab/UniMCP    # Nim
pip install lituus-unimcp                              # Python
```

For C, the build produces `libUniMCP.a` and `include/UniMCP.h`:

```bash
build/unigate clibStatic
cc -Iinclude your.c libUniMCP.a
```

The PyPI distribution is `lituus-unimcp`; the import name stays `unimcp`.
Those are two decisions, and the bare names are not all available.

## What runs here

Every Nim block on these pages is compiled and run when the book is built, and
the output shown is what the code produced. A change that breaks the API breaks
the docs build — so prose that outlived its API cannot ship.

That guarantee covers `nbCode` blocks and nothing else. A fenced block written
inside prose is a picture of code, not code.

## A server, whole

One tool, and the three messages a client sends before it can use it.
"""

nbCode:
  import std/strutils
  import UniMCP

  proc handler(name: string; arguments: JsonNode): JsonNode =
    if name != "shout":
      raise newException(RpcError, "unknown tool: " & name)
    toolResult(%*{"shouted": arguments["text"].getStr.toUpperAscii})

  var server = newServer(
    ServerInfo(name: "demo", title: "Demo", version: UniMCPVersion,
      description: "One tool, shouted back"),
    latestProtocol = "2025-11-25",
    supportedProtocols = @["2025-11-25"],
    tools = @[tool("shout", "Shout", "Upper-case a string",
      %*{"type": "object", "properties": {"text": {"type": "string"}},
         "required": ["text"]},
      readOnly = true, destructive = false, idempotent = true,
      openWorld = false)],
    handler = handler)

  for line in [
      """{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"demo","version":"1"}}}""",
      """{"jsonrpc":"2.0","method":"notifications/initialized"}""",
      """{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"shout","arguments":{"text":"hello"}}}"""]:
    let answer = server.handleLine(line)
    echo "<- ", (if answer.len > 0: answer else: "(notification: no reply)")

nbText: """
`handleLine` takes one line and gives one back. A real server hands that loop
to `serveStdio`, which reads stdin and writes stdout until the client goes
away — that is the whole transport.

## Supported versions

Nim 2.2 or later, on Linux, macOS and Windows. CPython 3.10 to 3.14, on the
same three. The `0.x` C ABI is not frozen.

## Licence, and where to ask

Apache-2.0. Contributions take a DCO sign-off; see `CONTRIBUTING.md`, and
`CODE_OF_CONDUCT.md` for conduct. Questions and defects go to the repository's
issue tracker.
"""

nbSave
