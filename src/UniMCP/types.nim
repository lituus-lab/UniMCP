## SPDX-License-Identifier: Apache-2.0
import std/json

type
  ToolHandler* = proc(name: string; arguments: JsonNode): JsonNode {.closure.}

  ServerInfo* = object
    name*: string
    title*: string
    version*: string
    description*: string

  ToolDescriptor* = object
    name*: string
    title*: string
    description*: string
    inputSchema*: JsonNode
    annotations*: JsonNode

  Server* = object
    info*: ServerInfo
    instructions*: string
    latestProtocol*: string
    supportedProtocols*: seq[string]
    tools*: seq[ToolDescriptor]
    handler*: ToolHandler
    initializeAccepted*: bool
    initialized*: bool

  RpcError* = object of ValueError

proc tool*(name, title, description: string; inputSchema: JsonNode;
    readOnly, destructive, idempotent, openWorld: bool): ToolDescriptor =
  ToolDescriptor(name: name, title: title, description: description,
    inputSchema: inputSchema, annotations: %*{
      "readOnlyHint": readOnly,
      "destructiveHint": destructive,
      "idempotentHint": idempotent,
      "openWorldHint": openWorld
    })

proc toolResult*(data: JsonNode; isError = false; text = ""): JsonNode =
  let rendered = if text.len > 0: text else: $data
  result = %*{"content": [{"type": "text", "text": rendered}],
    "isError": isError}
  # `structuredContent` is an object or it is not there: the protocol allows no
  # other shape, and a strict client rejects the whole response rather than the
  # one field. The rendering above still carries the value, whatever its shape.
  if data != nil and data.kind == JObject:
    result["structuredContent"] = data
