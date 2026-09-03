## SPDX-License-Identifier: Apache-2.0
import std/[json, strutils]
import UniMCP/types

proc response(id, payload: JsonNode): JsonNode =
  %*{"jsonrpc": "2.0", "id": id, "result": payload}

proc rpcError(id: JsonNode; code: int; message: string): JsonNode =
  %*{"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}

proc validId(id: JsonNode): bool =
  id.kind in {JString, JInt}

proc objectField(message: JsonNode; key: string): JsonNode =
  if not message.hasKey(key):
    raise newException(RpcError, "required object argument: " & key)
  if message[key].kind != JObject:
    raise newException(RpcError, "expected object argument: " & key)
  message[key]

proc stringField(message: JsonNode; key: string): string =
  if message.kind != JObject or not message.hasKey(key) or message[key].kind != JString:
    raise newException(RpcError, "required string argument: " & key)
  message[key].getStr

proc toolList(server: Server): JsonNode =
  var tools = newJArray()
  for descriptor in server.tools:
    tools.add(%*{"name": descriptor.name, "title": descriptor.title,
      "description": descriptor.description,
      "inputSchema": descriptor.inputSchema,
      "annotations": descriptor.annotations})
  %*{"tools": tools}

proc newServer*(info: ServerInfo;
    latestProtocol: string;
    supportedProtocols: seq[string];
    tools: seq[ToolDescriptor];
    handler: ToolHandler;
    instructions = ""): Server =
  if latestProtocol.len == 0 or latestProtocol notin supportedProtocols:
    raise newException(ValueError, "latest protocol must be included in supported protocols")
  if handler == nil:
    raise newException(ValueError, "tool handler is required")
  var names: seq[string] = @[]
  for descriptor in tools:
    if descriptor.name.len == 0 or descriptor.name in names:
      raise newException(ValueError, "tool names must be non-empty and unique")
    if descriptor.inputSchema == nil or descriptor.inputSchema.kind != JObject:
      raise newException(ValueError, "tool input schema must be an object")
    names.add(descriptor.name)
  result = Server(info: info, instructions: instructions,
    latestProtocol: latestProtocol,
    supportedProtocols: supportedProtocols, tools: tools, handler: handler)

proc handle*(server: var Server; message: JsonNode): JsonNode =
  if message.kind != JObject:
    return rpcError(newJNull(), -32600, "Invalid Request")
  let hasId = message.hasKey("id")
  let id = if hasId: message["id"] else: newJNull()
  let version = message.getOrDefault("jsonrpc")
  let rpc = version != nil and version.kind == JString and version.getStr == "2.0"
  if (hasId and not id.validId) or not rpc or
      not message.hasKey("method") or message["method"].kind != JString:
    return rpcError(id, -32600, "Invalid Request")
  let rpcMethod = message["method"].getStr
  if not hasId:
    if rpcMethod == "notifications/initialized" and server.initializeAccepted:
      server.initialized = true
    return nil
  try:
    if not server.initialized and rpcMethod notin ["initialize", "ping"]:
      return rpcError(id, -32002, "Server not initialized")
    case rpcMethod
    of "initialize":
      let params = message.objectField("params")
      let requested = params.stringField("protocolVersion")
      discard params.objectField("capabilities")
      discard params.objectField("clientInfo")
      let negotiated = if requested in server.supportedProtocols: requested else:
        server.latestProtocol
      server.initializeAccepted = true
      return response(id, %*{"protocolVersion": negotiated,
        "capabilities": {"tools": {"listChanged": false}},
        "serverInfo": {"name": server.info.name, "title": server.info.title,
          "version": server.info.version,
          "description": server.info.description},
        "instructions": server.instructions})
    of "ping": return response(id, newJObject())
    of "tools/list": return response(id, server.toolList)
    of "tools/call":
      let params = message.objectField("params")
      let name = params.stringField("name")
      let arguments = if params.hasKey("arguments"): params[
          "arguments"] else: newJObject()
      if arguments.kind != JObject:
        raise newException(RpcError, "expected object argument: arguments")
      return response(id, server.handler(name, arguments))
    else: return rpcError(id, -32601, "Method not found")
  except RpcError as error:
    if rpcMethod == "tools/call":
      return response(id, toolResult(%*{"error": error.msg}, true))
    return rpcError(id, -32602, error.msg)
  except KeyError as error:
    return rpcError(id, -32602, error.msg)
  except CatchableError as error:
    if rpcMethod == "tools/call":
      return response(id, toolResult(%*{"error": error.msg}, true))
    return rpcError(id, -32603, "Internal error: " & error.msg)

proc handleLine*(server: var Server; line: string): string =
  const maxMessageBytes = 4 * 1024 * 1024
  if line.len > maxMessageBytes:
    return $rpcError(newJNull(), -32600, "Request exceeds maximum size")
  try:
    let answer = server.handle(parseJson(line))
    if answer != nil: result = $answer
  except JsonParsingError:
    result = $rpcError(newJNull(), -32700, "Parse error")

proc serveStdio*(server: var Server) =
  var line: string
  while stdin.readLine(line):
    if line.strip.len == 0: continue
    let answer = server.handleLine(line)
    if answer.len > 0:
      stdout.writeLine(answer)
      stdout.flushFile
