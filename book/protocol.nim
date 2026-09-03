# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Protocol"

nbText: """
# Protocol

The supported surface is MCP over JSON-RPC 2.0, one message per line. UniMCP
advertises tools and nothing else: prompts and resources stay absent until
there is a tested consumer contract for them, because an advertised capability
that half-works is worse for a client than one that is not there.

## The errors, and when each one is the answer

| Code | Meaning | Sent when |
|---|---|---|
| `-32700` | Parse error | the line is not JSON |
| `-32600` | Invalid Request | not JSON-RPC 2.0, no method, or an identifier that is neither string nor integer |
| `-32601` | Method not found | a method this server does not implement |
| `-32602` | Invalid params | a required argument is missing or of the wrong shape |
| `-32603` | Internal error | the server itself failed |
| `-32002` | Not initialized | anything but `initialize` or `ping`, before the handshake |

Each of these is produced below rather than described.
"""

nbCode:
  import UniMCP

  proc handler(name: string; arguments: JsonNode): JsonNode =
    toolResult(arguments)

  var server = newServer(ServerInfo(name: "errors", title: "Errors",
      version: "1.0.0", description: "One of each"),
    "2025-11-25", @["2025-11-25"],
    @[tool("t", "T", "d", %*{"type": "object"}, true, false, true, false)],
    handler)

  for label, line in {
      "not JSON": "{",
      "not JSON-RPC 2.0": """{"jsonrpc":"1.0","id":1,"method":"ping"}""",
      "a fractional id": """{"jsonrpc":"2.0","id":1.5,"method":"ping"}""",
      "before the handshake": """{"jsonrpc":"2.0","id":2,"method":"tools/list"}""",
      "initialize, no params": """{"jsonrpc":"2.0","id":3,"method":"initialize"}"""}.items:
    echo label, ": ", server.handleLine(line)

nbText: """
`ping` is the exception the table names: it answers before the handshake, which
is what makes it usable as a liveness check.
"""

nbCode:
  echo "ping: ", server.handleLine("""{"jsonrpc":"2.0","id":4,"method":"ping"}""")

nbText: """
## Notifications

A message without an `id` is a notification: it is acted on, and it is never
answered. `handleLine` returns an empty string, and a server writes nothing.
"""

nbCode:
  let answer = server.handleLine(
    """{"jsonrpc":"2.0","method":"notifications/initialized"}""")
  echo "reply length: ", answer.len

nbText: """
## Negotiation

`initialize` carries the protocol version the client wants. If the server
supports it, that is what both sides use; if not, the server answers with its
own latest rather than refusing — the client then decides whether it can work
with it.

## Size

A line longer than 4 MiB is refused with `-32600` before it is parsed. The
limit is on the transport rather than on any message, so a client cannot make
the server allocate its way out of memory by sending one enormous line.
"""

nbSave
