# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""unimcp — Python binding over the UniMCP C library.

Build a server from its description and a handler, then feed it the JSON-RPC
messages a client sends:

    server = unimcp.Server(
        info={"name": "demo", "version": "1.0.0",
              "latestProtocol": "2025-11-25",
              "supportedProtocols": ["2025-11-25"]},
        tools=[{"name": "shout",
                "inputSchema": {"type": "object",
                                "properties": {"text": {"type": "string"}},
                                "required": ["text"]}}],
        handler=lambda name, arguments: {"shouted": arguments["text"].upper()})
    server.handle('{"jsonrpc":"2.0","id":1,"method":"ping"}')
"""
from ._core import Server, version as _version_c, abi_version as _abi_c, ABI_VERSION

__version__ = _version_c().decode("ascii")


def version():
    """C library version string."""
    return _version_c().decode("ascii")


def abi_version():
    """C ABI generation the loaded library implements."""
    return _abi_c()


__all__ = ["Server", "version", "abi_version", "ABI_VERSION", "__version__"]
