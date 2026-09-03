# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Architecture"

nbText: """
# Architecture

UniMCP sits on the boundary between an application and an MCP client, and the
boundary is the whole design: what is on this side is the protocol, what is on
the other side is yours.

| UniMCP owns | Your application owns |
|---|---|
| JSON-RPC framing and identifiers | tool behaviour |
| the lifecycle and what it permits | application state |
| protocol negotiation | authentication |
| the tool registry and its descriptors | I/O, shell, filesystem |
| dispatch, and the errors it returns | what a tool is allowed to do |

## Three states, and one way into each

A server starts *created*. A valid `initialize` moves it to
*initialize-accepted*; only then does `notifications/initialized` move it to
*initialized*. Until that last step, everything but `initialize` and `ping` is
refused with `-32002`.

The two steps are separate on purpose: the client has to acknowledge the
version the server negotiated before the server will act on anything.
"""

nbCode:
  import UniMCP

  proc handler(name: string; arguments: JsonNode): JsonNode =
    toolResult(arguments)

  proc fresh(): Server =
    newServer(ServerInfo(name: "states", title: "States", version: "1.0.0",
      description: "The lifecycle, walked"),
      "2025-11-25", @["2025-11-25"],
      @[tool("t", "T", "d", %*{"type": "object"}, true, false, true, false)],
      handler)

  var server = fresh()
  const listTools = """{"jsonrpc":"2.0","id":9,"method":"tools/list"}"""

  echo "created:             ", server.handleLine(listTools)
  discard server.handleLine("""{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"c","version":"1"}}}""")
  echo "initialize-accepted: ", server.handleLine(listTools)
  discard server.handleLine("""{"jsonrpc":"2.0","method":"notifications/initialized"}""")
  echo "initialized:         ", server.handleLine(listTools)

nbText: """
The notification on its own does nothing — a client that sends it without
having initialized first is not believed.
"""

nbCode:
  var impatient = fresh()
  discard impatient.handleLine("""{"jsonrpc":"2.0","method":"notifications/initialized"}""")
  echo "notification first:  ", impatient.handleLine(listTools)

nbText: """
## The trust boundary

A tool handler is application code, called with arguments that came off the
wire. Completing the handshake proves a client speaks MCP; it proves nothing
about what that client should be allowed to do. Validate arguments in the
handler, and decide there what a tool may touch — UniMCP checks that a message
is well-formed, never that it is welcome.

The layering that keeps this honest is checked, not merely intended:
`vgraph.cfg` lists `types`, then `server`, then `c_api`, and `nimble
checkVGraph` fails on an import that climbs. The wire shapes know nothing of
the dispatcher; the dispatcher knows nothing of the C caller.
"""

nbSave
