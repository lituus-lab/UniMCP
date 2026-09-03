# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Author py/notebooks/quickstart.ipynb, then execute it so the committed file
carries real outputs for GitHub to render. Run from the repo root:

    python3 py/notebooks/build_quickstart.py

CI re-executes the notebook against an installed wheel; this script only
regenerates it after an API change."""
import os

import nbformat as nbf
from nbclient import NotebookClient

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "quickstart.ipynb")

CELLS = [
    ("md", """# UniMCP — Python quickstart

`unimcp` is a Cython extension over the UniMCP C ABI, shipped as a
self-contained wheel: the native library travels inside the package, so
installing it needs neither Nim nor a compiler.

```
pip install lituus-unimcp
```

UniMCP is a Model Context Protocol server, as a library. It owns the protocol —
JSON-RPC framing, the handshake, negotiation, the tool registry, dispatch — and
none of what makes a server yours.

CI executes this notebook against the wheel the release actually publishes, so
an output below that stops matching fails the build."""),
    ("md", "## The API"),
    ("code", """import json

import unimcp

unimcp.version(), unimcp.abi_version()"""),
    ("md", """## A server

Three things: what the server *is*, what tools it offers, and the callable that
runs them. The first two are the JSON documents the protocol itself defines."""),
    ("code", """def handler(name, arguments):
    if name != "shout":
        raise KeyError(name)
    return {"shouted": arguments["text"].upper()}


server = unimcp.Server(
    info={"name": "quickstart", "title": "Quickstart", "version": "1.0.0",
          "description": "One tool, shouted back",
          "latestProtocol": "2025-11-25",
          "supportedProtocols": ["2025-11-25", "2024-11-05"]},
    tools=[{"name": "shout", "title": "Shout",
            "description": "Upper-case a string",
            "inputSchema": {"type": "object",
                            "properties": {"text": {"type": "string"}},
                            "required": ["text"]},
            "readOnlyHint": True, "idempotentHint": True}],
    handler=handler)
type(server).__name__"""),
    ("md", """## The handshake

A client sends `initialize`, the server answers with the version both sides
will use, and the client acknowledges. Until it does, nothing else is served."""),
    ("code", """def send(method, params=None, id=None):
    message = {"jsonrpc": "2.0", "method": method}
    if id is not None:
        message["id"] = id
    if params is not None:
        message["params"] = params
    reply = server.handle(json.dumps(message))
    return json.loads(reply) if reply else None


send("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                    "clientInfo": {"name": "quickstart", "version": "1"}}, id=1)"""),
    ("md", """The server answered with `2024-11-05`: the client asked for a
version it supports, so that is the one in force. A version it does not know
is answered with its own latest instead of a refusal.

A notification carries no `id` and gets no reply — `handle` returns `None`."""),
    ("code", 'send("notifications/initialized")'),
    ("md", "## Discovery and dispatch"),
    ("code", 'send("tools/list", id=2)'),
    ("code", """send("tools/call",
     {"name": "shout", "arguments": {"text": "hello"}}, id=3)"""),
    ("md", """## When a call fails

A tool that fails is not a broken connection. MCP reports it *in the result*,
with `isError` set, so a model can read the failure and try something else."""),
    ("code", 'send("tools/call", {"name": "absent", "arguments": {}}, id=4)'),
    ("md", """The exception the handler raised is kept rather than dropped:"""),
    ("code", "repr(server.last_error)"),
    ("md", """## Errors that are the protocol's, not a tool's

A malformed line, a method that does not exist, a call before the handshake:
each has its own JSON-RPC code."""),
    ("code", """[json.loads(server.handle("{")),
 send("nope", id=5)]"""),
    ("md", """## A description that cannot work

Refused at construction, where the mistake is, rather than at the first
call."""),
    ("code", """try:
    unimcp.Server(info={}, tools=[], handler=handler)
except ValueError as exc:
    print("ValueError:", exc)"""),
    ("md", """## The C ABI underneath

The same engine is reachable from anything that speaks C — two JSON documents
and a function pointer:

```c
void *unimcp_server_new(const char *info, const char *tools,
                        unimcp_tool_handler handler, void *user_data);
const char *unimcp_server_handle(void *server, const char *line);
```

There a failure is a `NULL` return with the reason in `unimcp_last_error`,
because an exception must never unwind across an ABI boundary.

See `include/UniMCP.h`, and the book for the full picture."""),
]


def main():
    nb = nbf.v4.new_notebook()
    nb.cells = [
        nbf.v4.new_markdown_cell(src) if kind == "md" else nbf.v4.new_code_cell(src)
        for kind, src in CELLS
    ]
    nb.metadata["kernelspec"] = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    # Execute from the repo root, never from py/: there, `import unimcp`
    # would resolve to the py/unimcp source tree instead of the installed
    # package, and the notebook would stop testing what it claims to test.
    NotebookClient(nb, timeout=120, kernel_name="python3",
                   resources={"metadata": {"path": ROOT}}).execute()
    with open(OUT, "w") as f:
        nbf.write(nb, f)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
