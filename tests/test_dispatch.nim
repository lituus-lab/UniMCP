# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## What a well-behaved client never sends. test_protocol covers the session a
## client actually walks; this covers everything it can get wrong -- a server
## description that cannot work, a method that does not exist, a tool that
## fails -- because each of those is an answer the protocol specifies, not an
## exception a caller has to catch.
import std/[json, strutils, unittest]
import UniMCP

proc request(id: int; rpcMethod: string; params = newJObject()): JsonNode =
  %*{"jsonrpc": "2.0", "id": id, "method": rpcMethod, "params": params}

proc handler(name: string; arguments: JsonNode): JsonNode =
  case name
  of "echo": toolResult(arguments)
  of "labelled": toolResult(arguments, text = "a rendering of its own")
  of "listy": toolResult(%*[1, 2])
  of "broken": raise newException(ValueError, "the tool itself failed")
  else: raise newException(KeyError, "unknown tool: " & name)

proc oneTool(name: string): seq[ToolDescriptor] =
  @[tool(name, "T", "d", %*{"type": "object"}, true, false, true, false)]

proc fixture(): Server =
  newServer(ServerInfo(name: "fixture", title: "F", version: "1.0.0",
    description: "d"), "2025-11-25", @["2025-11-25"],
    oneTool("echo") & oneTool("labelled") & oneTool("listy") &
      oneTool("broken"), handler)

proc ready(): Server =
  result = fixture()
  discard result.handle(request(1, "initialize", %*{
    "protocolVersion": "2025-11-25", "capabilities": {},
    "clientInfo": {"name": "test", "version": "1"}}))
  discard result.handle(%*{"jsonrpc": "2.0",
      "method": "notifications/initialized"})

suite "a server that cannot work is refused at construction":
  test "the latest protocol must be one of the supported ones":
    expect ValueError:
      discard newServer(ServerInfo(), "2025-11-25", @["2024-11-05"],
        oneTool("echo"), handler)

  test "and must not be empty":
    expect ValueError:
      discard newServer(ServerInfo(), "", @[""], oneTool("echo"), handler)

  test "a handler is required":
    expect ValueError:
      discard newServer(ServerInfo(), "2025-11-25", @["2025-11-25"],
        oneTool("echo"), nil)

  test "tool names must be non-empty and unique":
    expect ValueError:
      discard newServer(ServerInfo(), "2025-11-25", @["2025-11-25"],
        oneTool(""), handler)
    expect ValueError:
      discard newServer(ServerInfo(), "2025-11-25", @["2025-11-25"],
        oneTool("echo") & oneTool("echo"), handler)

  test "an input schema must be an object declaring an object type":
    # The shape MCP publishes for a tool. An empty object and a schema of
    # another type both reach a client as a tool it cannot call correctly.
    for schema in [JsonNode(nil), %*[1], %*{}, %*{"type": "string"}]:
      expect ValueError:
        discard newServer(ServerInfo(), "2025-11-25", @["2025-11-25"],
          @[tool("t", "T", "d", schema, true, false, true, false)], handler)

suite "methods outside the session":
  test "ping needs no handshake":
    var server = fixture()
    check server.handle(request(1, "ping"))["result"].kind == JObject

  test "an unknown method is reported as one":
    var server = ready()
    check server.handle(request(2, "nope"))["error"]["code"].getInt == -32601

  test "a notification before initialize changes nothing":
    var server = fixture()
    # The engine only records the handshake once initialize has been accepted;
    # a notification arriving first is dropped rather than trusted.
    check server.handle(%*{"jsonrpc": "2.0",
        "method": "notifications/other"}) == nil
    check server.handle(request(1, "tools/list"))["error"]["code"].getInt == -32002

suite "tools/call, when the call goes wrong":
  test "arguments that are not an object are an error result":
    var server = ready()
    let answer = server.handle(request(2, "tools/call",
      %*{"name": "echo", "arguments": [1, 2]}))
    check answer["result"]["isError"].getBool

  test "omitted arguments default to an empty object":
    var server = ready()
    let answer = server.handle(request(3, "tools/call", %*{"name": "echo"}))
    check answer["result"]["structuredContent"] == newJObject()

  test "a tool that fails answers, and the server keeps serving":
    var server = ready()
    let failed = server.handle(request(4, "tools/call",
      %*{"name": "broken", "arguments": {}}))
    check failed["result"]["isError"].getBool
    check "the tool itself failed" in $failed["result"]
    check server.handle(request(5, "ping"))["result"].kind == JObject

  test "a tool nobody declared never reaches the handler":
    # -32602, decided by the engine before dispatch: the request named something
    # tools/list does not advertise, which is a bad parameter rather than a tool
    # that ran and failed. The handler would raise KeyError here, and that would
    # be an error result -- the wrong answer, so it must not be asked.
    var server = ready()
    check server.handle(request(6, "tools/call",
      %*{"name": "absent", "arguments": {}}))["error"]["code"].getInt == -32602

  test "structured content is an object, or it is not there":
    # The protocol allows no other shape; the rendering still carries the value.
    var server = ready()
    let listed = server.handle(request(8, "tools/call",
      %*{"name": "listy", "arguments": {}}))["result"]
    check not listed.hasKey("structuredContent")
    check listed["content"][0]["text"].getStr == "[1,2]"

  test "a tool may render its own text beside the structured content":
    var server = ready()
    let answer = server.handle(request(7, "tools/call",
      %*{"name": "labelled", "arguments": {"a": 1}}))
    check answer["result"]["content"][0]["text"].getStr == "a rendering of its own"
    check answer["result"]["structuredContent"]["a"].getInt == 1

suite "handleLine, the transport's own answers":
  test "a well-formed line is answered with one":
    var server = ready()
    let answer = parseJson(server.handleLine(
      """{"jsonrpc":"2.0","id":1,"method":"ping"}"""))
    check answer["id"].getInt == 1

  test "a notification is answered with nothing at all":
    var server = ready()
    check server.handleLine(
      """{"jsonrpc":"2.0","method":"notifications/initialized"}""") == ""

  test "a line that is not JSON is a parse error":
    var server = ready()
    check parseJson(server.handleLine("{"))["error"]["code"].getInt == -32700

  test "a line past the size limit is refused before it is parsed":
    # 4 MiB is the engine's ceiling; one byte past it must not be parsed, which
    # is the whole point of checking the length first.
    var server = ready()
    let oversized = "\"" & repeat('x', 4 * 1024 * 1024) & "\""
    let answer = parseJson(server.handleLine(oversized))
    check answer["error"]["code"].getInt == -32600
    check "maximum size" in answer["error"]["message"].getStr

  test "an initialize missing its params is a bad argument":
    var server = fixture()
    check server.handleLine("""{"jsonrpc":"2.0","id":1,"method":"initialize"}"""
      ).parseJson["error"]["code"].getInt == -32602
