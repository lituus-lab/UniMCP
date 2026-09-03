// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
// Drives a whole MCP session from C: build a server, negotiate, list, call a
// tool, then the failure paths. What Nim's own suite cannot reach is exactly
// this -- the callback crossing back into C and the handles' lifetime.
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include "UniMCP.h"

static int failures = 0;

static void check(const char *name, int condition) {
  if (!condition) { printf("FAIL %s\n", name); failures++; }
  else printf("ok   %s\n", name);
}

static void check_str(const char *name, const char *got, const char *want) {
  if (got == NULL || strcmp(got, want) != 0) {
    printf("FAIL %s: got \"%s\" want \"%s\"\n", name, got ? got : "(null)", want);
    failures++;
  } else printf("ok   %s = \"%s\"\n", name, got);
}

static void check_has(const char *name, const char *got, const char *needle) {
  if (got == NULL || strstr(got, needle) == NULL) {
    printf("FAIL %s: \"%s\" does not contain \"%s\"\n",
           name, got ? got : "(null)", needle);
    failures++;
  } else printf("ok   %s contains \"%s\"\n", name, needle);
}

// The tool the server dispatches to. `calls` counts them through user_data,
// which is how this test proves the pointer survives the round trip.
static char answer[256];
static const char *echo_tool(const char *name, const char *arguments,
                             void *user_data) {
  (*(int *)user_data)++;
  if (strcmp(name, "echo") != 0) return NULL; /* reported as a failed call */
  snprintf(answer, sizeof answer, "{\"seen\":%s}", arguments);
  return answer;
}

static const char *INFO =
    "{\"name\":\"c-fixture\",\"title\":\"C fixture\",\"version\":\"1.0.0\","
    "\"description\":\"Driven from C\",\"instructions\":\"Say hello\","
    "\"latestProtocol\":\"2025-11-25\","
    "\"supportedProtocols\":[\"2025-11-25\",\"2024-11-05\"]}";
static const char *TOOLS =
    "[{\"name\":\"echo\",\"title\":\"Echo\",\"description\":\"Return what it is given\","
    "\"inputSchema\":{\"type\":\"object\"},\"readOnlyHint\":true,"
    "\"idempotentHint\":true}]";

int main(void) {
  check_str("version", unimcp_version(), UNIMCP_VERSION);
  check("abi generation", unimcp_abi_version() == UNIMCP_ABI_VERSION);
  check_str("no error yet", unimcp_last_error(), "");

  int calls = 0;
  void *server = unimcp_server_new(INFO, TOOLS, echo_tool, &calls);
  check("server built", server != NULL);
  if (server == NULL) { printf("%s\n", unimcp_last_error()); return 1; }

  const char *reply = unimcp_server_handle(server,
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":"
      "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},"
      "\"clientInfo\":{\"name\":\"c\",\"version\":\"1\"}}}");
  check_has("initialize negotiates the client's version", reply, "\"2024-11-05\"");

  reply = unimcp_server_handle(server,
      "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}");
  check_str("a notification has no reply", reply, "");

  reply = unimcp_server_handle(server, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}");
  check_has("tools/list names the tool", reply, "\"echo\"");
  check_has("the hints crossed as declared", reply, "\"readOnlyHint\":true");

  reply = unimcp_server_handle(server,
      "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":"
      "{\"name\":\"echo\",\"arguments\":{\"value\":\"from C\"}}}");
  check_has("the C callback answered", reply, "from C");
  check("the callback ran once", calls == 1);

  // A tool the callback rejects: an error result, not a dead server.
  reply = unimcp_server_handle(server,
      "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":"
      "{\"name\":\"absent\",\"arguments\":{}}}");
  check_has("a rejected call is an error result", reply, "\"isError\":true");

  reply = unimcp_server_handle(server, "{ not json");
  check_has("malformed input is answered, not rejected", reply, "-32700");

  reply = unimcp_server_handle(server, NULL);
  check("a NULL message reports failure", reply == NULL);
  check_has("and says why", unimcp_last_error(), "NULL argument");

  // The server survived every one of those.
  reply = unimcp_server_handle(server, "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"ping\"}");
  check_has("still serving", reply, "\"result\"");

  unimcp_server_free(server);
  unimcp_server_free(NULL); /* documented no-op */

  check("a server with no protocols is refused",
        unimcp_server_new("{}", "[]", echo_tool, &calls) == NULL);
  check_has("and says why", unimcp_last_error(), "supportedProtocols");
  check("a NULL handler is refused",
        unimcp_server_new(INFO, TOOLS, NULL, &calls) == NULL);
  check("two tools of one name are refused",
        unimcp_server_new(INFO,
            "[{\"name\":\"a\",\"inputSchema\":{}},{\"name\":\"a\",\"inputSchema\":{}}]",
            echo_tool, &calls) == NULL);

  if (failures == 0) { printf("\nAll C ABI tests passed.\n"); return 0; }
  printf("\n%d C ABI test(s) FAILED.\n", failures);
  return 1;
}
