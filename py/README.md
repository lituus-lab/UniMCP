<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# unimcp — Python binding

Distributed as `lituus-unimcp`, imported as `unimcp`: the two names
are separate decisions, and the bare names are not all available on PyPI.

```bash
pip install lituus-unimcp
```

From a checkout, `build/unigate pyTest` builds the extension and runs the tests
in one step. The pieces, if you want them apart:

```bash
build/unigate pyLib          # the C library the extension links against
build/unigate buildCython    # the extension, in place
build/unigate pyWheel        # a wheel in py/dist/
```

```python
import json, unimcp

def handler(name, arguments):
    if name != "shout":
        raise KeyError(name)
    return {"shouted": arguments["text"].upper()}

server = unimcp.Server(
    info={"name": "demo", "version": "1.0.0",
          "latestProtocol": "2025-11-25",
          "supportedProtocols": ["2025-11-25"]},
    tools=[{"name": "shout",
            "inputSchema": {"type": "object",
                            "properties": {"text": {"type": "string"}},
                            "required": ["text"]}}],
    handler=handler)

server.handle(json.dumps({"jsonrpc": "2.0", "id": 1, "method": "ping"}))
```

`handle` returns the reply as a string, or `None` for a notification. A handler
that raises is answered with the protocol's own error result — that is what MCP
prescribes, and raising here would end a serving loop on its first bad call;
the exception is kept on `server.last_error` rather than dropped.

A description that cannot work raises `ValueError` at construction.
