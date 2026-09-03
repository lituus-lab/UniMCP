// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
// The same session as examples/demo.nim, through the C ABI: the server lives
// in UniMCP, the tool lives here, and JSON strings are all that cross.
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "UniMCP.h"

static char answer[512];

static const char *shout(const char *name, const char *arguments,
                         void *user_data) {
  (void)user_data;
  if (strcmp(name, "shout") != 0) return NULL; /* -> an error result */
  snprintf(answer, sizeof answer, "{\"shouted\":\"");
  size_t at = strlen(answer);
  /* The arguments arrive as JSON; this demo reads the one member it declared
     without pulling in a parser. */
  const char *text = strstr(arguments, "\"text\":\"");
  if (text != NULL) {
    text += strlen("\"text\":\"");
    while (*text != '"' && *text != '\0' && at + 2 < sizeof answer)
      answer[at++] = (char)toupper((unsigned char)*text++);
  }
  snprintf(answer + at, sizeof answer - at, "\"}");
  return answer;
}

int main(void) {
  printf("UniMCP %s (ABI %d)\n", unimcp_version(), unimcp_abi_version());

  void *server = unimcp_server_new(
      "{\"name\":\"demo\",\"title\":\"UniMCP demo\",\"version\":\"" UNIMCP_VERSION "\","
      "\"description\":\"One tool, shouted back\","
      "\"instructions\":\"Call shout with any text.\","
      "\"latestProtocol\":\"2025-11-25\",\"supportedProtocols\":[\"2025-11-25\"]}",
      "[{\"name\":\"shout\",\"title\":\"Shout\",\"description\":\"Upper-case a string\","
      "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"text\":{\"type\":\"string\"}},"
      "\"required\":[\"text\"]},\"readOnlyHint\":true,\"idempotentHint\":true}]",
      shout, NULL);
  if (server == NULL) {
    printf("could not build the server: %s\n", unimcp_last_error());
    return 1;
  }

  const char *session[] = {
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":"
      "{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{},"
      "\"clientInfo\":{\"name\":\"demo\",\"version\":\"1\"}}}",
      "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}",
      "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}",
      "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":"
      "{\"name\":\"shout\",\"arguments\":{\"text\":\"hello\"}}}",
      "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":"
      "{\"name\":\"absent\",\"arguments\":{}}}"};

  for (size_t i = 0; i < sizeof session / sizeof session[0]; i++) {
    const char *reply = unimcp_server_handle(server, session[i]);
    printf("-> %s\n", session[i]);
    if (reply == NULL) printf("<- failed: %s\n", unimcp_last_error());
    else if (reply[0] == '\0') printf("<- (no reply: notification)\n");
    else printf("<- %s\n", reply);
  }

  unimcp_server_free(server);
  return 0;
}
