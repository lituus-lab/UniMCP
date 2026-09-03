// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#ifndef UNIMCP_H
#define UNIMCP_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNIMCP_VERSION_MAJOR 0
#define UNIMCP_VERSION_MINOR 1
#define UNIMCP_VERSION_PATCH 0
#define UNIMCP_VERSION "0.1.0"

#define UNIMCP_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNIMCP_VERSION_MAJOR > (ma)) || \
   (UNIMCP_VERSION_MAJOR == (ma) && UNIMCP_VERSION_MINOR > (mi)) || \
   (UNIMCP_VERSION_MAJOR == (ma) && UNIMCP_VERSION_MINOR == (mi) && \
    UNIMCP_VERSION_PATCH >= (pa)))

/* C ABI generation. A consumer built against another one is not compatible. */
#define UNIMCP_ABI_VERSION 1

/* Static version string; do not free. */
const char *unimcp_version(void);

/* The generation this library implements; compare against UNIMCP_ABI_VERSION. */
int unimcp_abi_version(void);

/* The message for the failure the last call reported, or "" when none has.
 * Borrowed: this library owns it, and the next failing call overwrites it. */
const char *unimcp_last_error(void);

/* What UniMCP calls for `tools/call`.
 *
 * `name` is the tool, `arguments` its arguments as a JSON object; both are
 * borrowed for the duration of the call. Return the tool's structured result
 * as a JSON object -- UniMCP wraps it in the protocol's content envelope and
 * copies it before returning -- or NULL to report the call as failed, which
 * reaches the client as an error result rather than tearing down the server.
 * `user_data` is whatever was handed to unimcp_server_new. */
typedef const char *(*unimcp_tool_handler)(const char *name,
                                           const char *arguments,
                                           void *user_data);

/* A server from its JSON description, or NULL with the reason in
 * unimcp_last_error. Free with unimcp_server_free.
 *
 * `info` is an object:
 *   {"name": "...", "title": "...", "version": "...", "description": "...",
 *    "instructions": "...", "latestProtocol": "2025-11-25",
 *    "supportedProtocols": ["2025-11-25", "2024-11-05"]}
 * `latestProtocol` must appear in `supportedProtocols`; the string members are
 * optional and default to empty.
 *
 * `tools` is an array of objects:
 *   {"name": "...", "title": "...", "description": "...",
 *    "inputSchema": {"type": "object", ...},
 *    "readOnlyHint": true, "destructiveHint": false,
 *    "idempotentHint": true, "openWorldHint": false}
 * Names must be non-empty and unique, and each inputSchema an object; the
 * hints default to false.
 *
 * Both documents are read during this call and not retained. */
void *unimcp_server_new(const char *info, const char *tools,
                        unimcp_tool_handler handler, void *user_data);

/* Release a server. NULL is a no-op; freeing twice is not. */
void unimcp_server_free(void *server);

/* The reply to one JSON-RPC message, "" for a notification (which has no
 * reply), or NULL with the reason in unimcp_last_error.
 *
 * Borrowed: the returned pointer belongs to `server` and stays valid until the
 * next unimcp_server_handle call on that same server. Copy it to keep it.
 * A message that is not valid JSON is answered, not rejected: the reply is the
 * protocol's own -32700 parse error. */
const char *unimcp_server_handle(void *server, const char *line);

#ifdef __cplusplus
}
#endif

#endif /* UNIMCP_H */
