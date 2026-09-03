# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Tools"

nbText: """
# Tools

A tool is two things: a descriptor a client can read, and a handler UniMCP
calls. The descriptor is what `tools/list` returns; the handler is your code.

## Declaring one

`tool` builds the descriptor. The four booleans are MCP's annotation hints —
they tell a client what calling the tool means, and they are hints, not
enforcement: nothing stops a handler from ignoring what its own descriptor
promised.

| Hint | Says |
|---|---|
| `readOnly` | the call changes nothing |
| `destructive` | it may remove or overwrite |
| `idempotent` | calling twice is the same as once |
| `openWorld` | it reaches outside this process |
"""

nbCode:
  import UniMCP

  let celsius = tool("to_celsius", "To Celsius",
    "Convert degrees Fahrenheit to Celsius",
    %*{"type": "object",
       "properties": {"f": {"type": "number"}},
       "required": ["f"]},
    readOnly = true, destructive = false, idempotent = true, openWorld = false)

  echo celsius.annotations

nbText: """
## Handling one

The handler receives the tool's name and its arguments, and returns what
`toolResult` builds: the structured content, plus the text rendering a client
displays. Passing `text` overrides that rendering; leaving it out renders the
data itself.
"""

nbCode:
  proc handler(name: string; arguments: JsonNode): JsonNode =
    if name != "to_celsius":
      raise newException(RpcError, "unknown tool: " & name)
    if arguments.kind != JObject or not arguments.hasKey("f") or
        arguments["f"].kind notin {JInt, JFloat}:
      raise newException(RpcError, "required number argument: f")
    let c = (arguments["f"].getFloat - 32.0) * 5.0 / 9.0
    toolResult(%*{"celsius": c}, text = $c & " °C")

  var server = newServer(ServerInfo(name: "weather", title: "Weather",
      version: "1.0.0", description: "One conversion"),
    "2025-11-25", @["2025-11-25"], @[celsius], handler)
  discard server.handleLine("""{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"c","version":"1"}}}""")
  discard server.handleLine("""{"jsonrpc":"2.0","method":"notifications/initialized"}""")

  echo server.handleLine("""{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"to_celsius","arguments":{"f":212}}}""")

nbText: """
## When a call fails

A tool that fails is not a transport failure. MCP reports it *in the result*,
with `isError` set — which is what lets a model read the failure and try
something else, instead of the connection dropping under it.

A tool that does not exist is a different failure, and gets a different answer:
the engine refuses it with `-32602` before your handler is asked. Your handler
is never called for a name `tools/list` did not advertise, so it never has to
decide what to do about one.

| What happened | Client receives |
|---|---|
| the handler raised `RpcError` | an error **result**, `isError: true` |
| the handler raised any other `CatchableError` | an error **result**, `isError: true` |
| the tool is not registered | `-32602`, invalid params — before dispatch |
| the handler raised `KeyError` | `-32602`, invalid params |

`KeyError` keeps its own row because it is what `[]` raises on a missing member:
a handler that reads an argument which is not there is reporting a bad request,
not a tool that ran and failed.
"""

nbCode:
  echo "wrong shape:  ", server.handleLine("""{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"to_celsius","arguments":{"f":"hot"}}}""")
  echo "no such tool: ", server.handleLine("""{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"absent","arguments":{}}}""")

nbText: """
Either way the server is still serving: neither answer ends the session.
"""

nbCode:
  echo "still alive:  ", server.handleLine("""{"jsonrpc":"2.0","id":5,"method":"ping"}""")

nbText: """
## What is refused before the server exists

`newServer` will not build a server that cannot work: a latest protocol that is
not among the supported ones, no handler, a tool with no name, two tools of one
name, or an input schema that is not an object declaring `"type": "object"` —
the shape MCP publishes for a tool. Each raises `ValueError` at construction,
where the mistake is, rather than at the first call.
"""

nbSave
