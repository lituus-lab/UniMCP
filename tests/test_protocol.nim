## SPDX-License-Identifier: Apache-2.0
import std/[json, unittest]
import UniMCP

proc request(id: int; rpcMethod: string; params = newJObject()): JsonNode =
  %*{"jsonrpc": "2.0", "id": id, "method": rpcMethod, "params": params}

proc handler(name: string; arguments: JsonNode): JsonNode =
  if name != "echo": raise newException(KeyError, "unknown tool: " & name)
  if arguments.kind != JObject or not arguments.hasKey("value") or
      arguments["value"].kind != JString:
    raise newException(RpcError, "required string argument: value")
  toolResult(%*{"value": arguments["value"].getStr})

proc fixtureServer(): Server =
  newServer(ServerInfo(name: "fixture", title: "Fixture", version: "1.0.0",
    description: "Portable protocol fixture"), "2025-11-25",
    @["2025-11-25", "2024-11-05"],
    @[tool("echo", "Echo", "Return a string", %*{"type": "object",
      "properties": {"value": {"type": "string"}}, "required": ["value"]},
      true, false, true, false)], handler, "Fixture instructions")

suite "JSON-RPC and MCP stdio server":
  test "negotiates initialization and dispatches a tool":
    var server = fixtureServer()
    let initialized = server.handle(request(1, "initialize", %*{
      "protocolVersion": "2024-11-05", "capabilities": {},
      "clientInfo": {"name": "test", "version": "1"}}))
    check initialized["result"]["protocolVersion"].getStr == "2024-11-05"
    discard server.handle(%*{"jsonrpc": "2.0",
        "method": "notifications/initialized"})
    let listed = server.handle(request(2, "tools/list"))
    check listed["result"]["tools"][0]["name"].getStr == "echo"
    let called = server.handle(request(3, "tools/call", %*{
      "name": "echo", "arguments": {"value": "portable"}}))
    check called["result"]["structuredContent"]["value"].getStr == "portable"

  test "returns stable errors":
    var server = fixtureServer()
    check parseJson(server.handleLine("{"))["error"]["code"].getInt == -32700
    check server.handle(%*[])["error"]["code"].getInt == -32600
    check server.handle(request(1, "tools/list"))["error"]["code"].getInt == -32002
    let invalid = server.handle(request(2, "initialize", %*{
        "protocolVersion": 1}))
    check invalid["error"]["code"].getInt == -32602

  test "requires the initialization handshake":
    var server = fixtureServer()
    discard server.handle(%*{"jsonrpc": "2.0",
        "method": "notifications/initialized"})
    check server.handle(request(1, "tools/list"))["error"]["code"].getInt == -32002
    let missing = server.handle(request(2, "initialize", %*{
        "protocolVersion": "2025-11-25"}))
    check missing["error"]["code"].getInt == -32602
    discard server.handle(request(4, "initialize", %*{
      "protocolVersion": "2025-11-25", "capabilities": {},
      "clientInfo": {"name": "test", "version": "1"}}))
    discard server.handle(%*{"jsonrpc": "2.0",
        "method": "notifications/initialized"})
    check server.handle(request(3, "tools/list"))["result"]["tools"].len == 1

  test "rejects unsupported request identifiers":
    var server = fixtureServer()
    let floating = server.handle(%*{"jsonrpc": "2.0", "id": 1.5,
        "method": "ping"})
    check floating["error"]["code"].getInt == -32600
