# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Cython layer over the UniMCP C ABI.

Two things cross the boundary and nothing else: JSON strings, and one function
pointer. The pointer is the reason this is Cython rather than ctypes -- the
tool handler is a Python callable the Nim engine calls back into, and a ctypes
callback would pay a trampoline per call and lose the exception.
"""
import json as _json

cdef extern from "UniMCP.h":
    const char *unimcp_version()
    int unimcp_abi_version()
    const char *unimcp_last_error()
    # The generation this header declares, read from the header rather than
    # restated here: one copy fewer to drift.
    int UNIMCP_ABI_VERSION
    ctypedef const char *(*unimcp_tool_handler)(
        const char *name, const char *arguments, void *user_data) noexcept
    void *unimcp_server_new(const char *info, const char *tools,
                            unimcp_tool_handler handler, void *user_data)
    void unimcp_server_free(void *server)
    const char *unimcp_server_handle(void *server, const char *line)


ABI_VERSION = UNIMCP_ABI_VERSION


cdef const char *_dispatch(const char *name, const char *arguments,
                           void *user_data) noexcept:
    """What the engine calls for `tools/call`; returns NULL on any failure.

    Called synchronously from inside `Server.handle`, so the GIL is held and
    the instance is alive for the whole call.
    """
    cdef Server server = <Server>user_data
    try:
        answer = server._handler(name.decode("utf-8"),
                                 _json.loads(arguments.decode("utf-8")))
        # Held on the instance: the pointer handed back must outlive this
        # function, and a local bytes object would be freed on return.
        server._answer = _json.dumps(answer).encode("utf-8")
    except Exception as error:
        # NULL is how the ABI reports a failed call, and the client receives a
        # protocol error result -- which is what MCP prescribes and what keeps
        # a server loop alive. The exception itself would otherwise be lost, so
        # it is kept on the instance for `last_error` to hand back.
        server._error = error
        return NULL
    return server._answer


cdef class Server:
    """An MCP server. `info` and `tools` are the JSON documents the C ABI's
    header describes; `handler` is called as handler(name, arguments)."""
    cdef void *_handle
    cdef object _handler
    cdef object _error
    cdef bytes _answer

    def __cinit__(self, info, tools, handler):
        self._handle = NULL
        self._answer = b""
        self._error = None
        if not callable(handler):
            raise TypeError("handler must be callable")
        self._handler = handler
        cdef bytes info_json = _json.dumps(info).encode("utf-8")
        cdef bytes tools_json = _json.dumps(tools).encode("utf-8")
        self._handle = unimcp_server_new(info_json, tools_json, _dispatch,
                                         <void *>self)
        if self._handle == NULL:
            raise ValueError(unimcp_last_error().decode("utf-8"))

    def __dealloc__(self):
        if self._handle != NULL:
            unimcp_server_free(self._handle)
            self._handle = NULL

    @property
    def last_error(self):
        """The exception the last tool handler raised, or None.

        A handler that raises is answered with the protocol's own error result
        -- that is what MCP prescribes, and raising here instead would end a
        serving loop on the first bad call. The exception is kept rather than
        dropped, so a failure inside the handler stays diagnosable.
        """
        return self._error

    def handle(self, line):
        """The reply to one JSON-RPC message, or None for a notification."""
        cdef bytes encoded = line.encode("utf-8")
        self._error = None
        cdef const char *reply = unimcp_server_handle(self._handle, encoded)
        if reply == NULL:
            raise RuntimeError(unimcp_last_error().decode("utf-8"))
        answer = reply.decode("utf-8")
        return answer if answer else None


def version():
    return unimcp_version()


def abi_version():
    return unimcp_abi_version()
