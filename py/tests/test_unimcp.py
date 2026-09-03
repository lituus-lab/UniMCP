# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""The Python surface, driven as a client drives an MCP server."""
import json

import pytest

import unimcp

INFO = {
    "name": "py-fixture",
    "title": "Python fixture",
    "version": "1.0.0",
    "description": "Driven from pytest",
    "instructions": "Call echo with any string",
    "latestProtocol": "2025-11-25",
    "supportedProtocols": ["2025-11-25", "2024-11-05"],
}
TOOLS = [{
    "name": "echo",
    "title": "Echo",
    "description": "Return what it is given",
    "inputSchema": {"type": "object",
                    "properties": {"value": {"type": "string"}},
                    "required": ["value"]},
    "readOnlyHint": True,
    "idempotentHint": True,
}]


def echo(name, arguments):
    if name != "echo":
        raise KeyError(f"unknown tool: {name}")
    return {"value": arguments["value"]}


def request(id, method, params=None):
    message = {"jsonrpc": "2.0", "id": id, "method": method}
    if params is not None:
        message["params"] = params
    return json.dumps(message)


@pytest.fixture
def server():
    return unimcp.Server(info=INFO, tools=TOOLS, handler=echo)


def initialized(server, protocol="2025-11-25"):
    reply = json.loads(server.handle(request(1, "initialize", {
        "protocolVersion": protocol, "capabilities": {},
        "clientInfo": {"name": "pytest", "version": "1"}})))
    server.handle(json.dumps(
        {"jsonrpc": "2.0", "method": "notifications/initialized"}))
    return reply


def test_version_and_abi():
    assert unimcp.version() == "0.1.0"
    assert unimcp.abi_version() == unimcp.ABI_VERSION


def test_negotiates_the_client_version(server):
    assert initialized(server, "2024-11-05")["result"]["protocolVersion"] == "2024-11-05"


def test_falls_back_to_the_latest_protocol(server):
    # An unknown version is not refused: the server answers with its own.
    assert initialized(server, "1999-01-01")["result"]["protocolVersion"] == "2025-11-25"


def test_lists_the_declared_tools(server):
    initialized(server)
    listed = json.loads(server.handle(request(2, "tools/list")))["result"]["tools"]
    assert [t["name"] for t in listed] == ["echo"]
    assert listed[0]["annotations"]["readOnlyHint"] is True


def test_calls_back_into_python(server):
    initialized(server)
    called = json.loads(server.handle(request(3, "tools/call", {
        "name": "echo", "arguments": {"value": "from python"}})))
    assert called["result"]["structuredContent"]["value"] == "from python"


def test_a_notification_has_no_reply(server):
    assert server.handle(json.dumps(
        {"jsonrpc": "2.0", "method": "notifications/initialized"})) is None


def test_a_handler_that_raises_is_an_error_result(server):
    initialized(server)
    called = json.loads(server.handle(request(4, "tools/call", {
        "name": "absent", "arguments": {}})))
    # MCP reports a tool failure in the result, not as a transport error --
    # so the call answers, and the exception stays readable.
    assert called["result"]["isError"] is True
    assert isinstance(server.last_error, KeyError)


def test_malformed_input_is_answered(server):
    assert json.loads(server.handle("{ not json"))["error"]["code"] == -32700


def test_before_the_handshake_nothing_is_served(server):
    assert json.loads(server.handle(request(1, "tools/list")))["error"]["code"] == -32002


def test_a_bad_description_is_refused():
    with pytest.raises(ValueError, match="supportedProtocols"):
        unimcp.Server(info={}, tools=[], handler=echo)


def test_a_handler_must_be_callable():
    with pytest.raises(TypeError):
        unimcp.Server(info=INFO, tools=TOOLS, handler="not callable")


def test_duplicate_tool_names_are_refused():
    with pytest.raises(ValueError):
        unimcp.Server(info=INFO, tools=TOOLS + TOOLS, handler=echo)
