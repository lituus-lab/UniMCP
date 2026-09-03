# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, osproc, strutils]
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "The Python surface"

const Root = currentSourcePath().parentDir.parentDir

proc run(command: string): string =
  let (output, code) = execCmdEx("cd " & Root.quoteShell & " && " & command)
  result = output.strip
  if code != 0:
    raise newException(OSError,
      "book: `" & command & "` exited " & $code & "\n" & result)

nbText: """
# The Python surface

`unimcp.Server` takes the same two documents the C ABI takes — as Python
objects, serialized for you — and a callable. Dispatch crosses into Python and
back for every `tools/call`.

That crossing is why the binding is Cython rather than `ctypes`: the handler is
a callback the engine invokes, and a `ctypes` callback would pay a trampoline
on every call and lose the exception on the way out.
"""

nbCode:
  echo run("""PYTHONPATH=py python3 -c '
import json, unimcp

def handler(name, arguments):
    if name != "shout":
        raise KeyError(name)
    return {"shouted": arguments["text"].upper()}

server = unimcp.Server(
    info={"name": "demo", "title": "Demo", "version": unimcp.version(),
          "description": "One tool, shouted back",
          "latestProtocol": "2025-11-25",
          "supportedProtocols": ["2025-11-25"]},
    tools=[{"name": "shout", "title": "Shout", "description": "Upper-case a string",
            "inputSchema": {"type": "object"}, "readOnlyHint": True}],
    handler=handler)

print("version:", unimcp.version(), "ABI:", unimcp.abi_version())
server.handle(json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize",
    "params": {"protocolVersion": "2025-11-25", "capabilities": {},
               "clientInfo": {"name": "book", "version": "1"}}}))
server.handle(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}))
print(server.handle(json.dumps({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
    "params": {"name": "shout", "arguments": {"text": "hello"}}})))
'""")

nbText: """
## Where Python differs

Three differences a caller has to know, none of which is visible from a
signature:

- **A notification returns `None`, not `""`.** The C ABI answers a notification
  with an empty string; the binding turns that into `None`, because that is
  what a Python caller tests for.
- **A handler that raises does not raise here.** The call is answered with the
  protocol's error result — that is what MCP prescribes, and raising instead
  would end a serving loop on its first bad call. The exception is not dropped:
  it is kept on `server.last_error`.
- **A description that cannot work raises at construction.** `ValueError`, with
  the engine's own message — the same check the C ABI reports through
  `unimcp_last_error`.
"""

nbCode:
  echo run("""PYTHONPATH=py python3 -c '
import json, unimcp

def broken(name, arguments):
    raise RuntimeError("this tool is out of order")

server = unimcp.Server(
    info={"name": "d", "version": "1.0.0", "latestProtocol": "2025-11-25",
          "supportedProtocols": ["2025-11-25"]},
    tools=[{"name": "t", "inputSchema": {"type": "object"}}],
    handler=broken)
server.handle(json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize",
    "params": {"protocolVersion": "2025-11-25", "capabilities": {},
               "clientInfo": {"name": "book", "version": "1"}}}))
server.handle(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}))

print("notification ->", repr(server.handle(
    json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}))))
answer = json.loads(server.handle(json.dumps({"jsonrpc": "2.0", "id": 2,
    "method": "tools/call", "params": {"name": "t", "arguments": {}}})))
print("isError      ->", answer["result"]["isError"])
print("last_error   ->", repr(server.last_error))

try:
    unimcp.Server(info={}, tools=[], handler=broken)
except ValueError as exc:
    print("bad server   ->", exc)
'""")

nbText: """
## The distribution

`pip install lituus-unimcp`; the import name stays `unimcp`. The wheel bundles
the shared library beside the extension and finds it through an rpath relative
to it, so an installed package needs nothing else on the system. Building from
the sdist compiles the vendored Nim source instead, and needs Nim on `PATH`.
"""

nbSave
