# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## A one-tool MCP server, driven through the three messages a client sends
## before it can work: initialize, the initialized notification, tools/call.
## `serveStdio` is what a real server would call instead of feeding it lines.
import std/strutils
import UniMCP

proc handler(name: string; arguments: JsonNode): JsonNode =
  if name != "shout":
    raise newException(RpcError, "unknown tool: " & name)
  if arguments.kind != JObject or not arguments.hasKey("text") or
      arguments["text"].kind != JString:
    raise newException(RpcError, "required string argument: text")
  toolResult(%*{"shouted": arguments["text"].getStr.toUpperAscii})

when isMainModule:
  echo "UniMCP " & UniMCPVersion

  var server = newServer(
    ServerInfo(name: "demo", title: "UniMCP demo", version: UniMCPVersion,
      description: "One tool, shouted back"),
    "2025-11-25", @["2025-11-25"],
    @[tool("shout", "Shout", "Upper-case a string",
        %*{"type": "object", "properties": {"text": {"type": "string"}},
           "required": ["text"]},
        readOnly = true, destructive = false, idempotent = true,
        openWorld = false)],
    handler, "Call shout with any text.")

  for line in [
      """{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"demo","version":"1"}}}""",
      """{"jsonrpc":"2.0","method":"notifications/initialized"}""",
      """{"jsonrpc":"2.0","id":2,"method":"tools/list"}""",
      """{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"shout","arguments":{"text":"hello"}}}""",
      """{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"absent","arguments":{}}}"""]:
    let answer = server.handleLine(line)
    echo "-> " & line
    echo "<- " & (if answer.len > 0: answer else: "(no reply: notification)")
