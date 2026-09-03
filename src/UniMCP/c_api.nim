# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## C ABI for UniMCP. Built --app:staticlib/--app:lib --noMain --mm:arc
## -d:release. Keep in sync with include/UniMCP.h; tests/c links the header
## against this lib, so a header that drifts fails to compile rather than at a
## caller's site.
##
## The Nim API is JSON in, JSON out; so is this one. A server is described by
## two JSON documents and a C function pointer, and every message crosses as a
## NUL-terminated string, which is what lets a caller in any language drive the
## protocol without a struct layout to agree on.
##
## No Nim exception crosses this boundary: `{.raises: [].}` on every entry
## point is what proves it rather than a convention that has to be remembered.
import std/json
import ../UniMCP

const
  UniMCPVersionC: cstring = "0.1.0"
  UniMCPAbiVersion: cint = 1

# Unmangled C symbols, C calling convention, exported from the shared lib.
# --noMain suppresses the generated entry point and with it every auto-init
# hook: neither the static nor the shared build emits a DllMain or an ELF
# constructor, so nothing initializes the Nim runtime. The first entry point
# then enters Nim code whose globals were never set up. The shared build was
# assumed to be covered by a loader hook it does not have -- its registries
# stayed empty and the contrast entry answered nan. Every --noMain task passes
# -d:noAutoInit; an ordinary executable linking this module must not, since its
# own main already ran NimMain.
when defined(noAutoInit):
  # A once primitive, not a plain flag: two threads reaching an entry point
  # together would both see the flag unset, both call NimMain, and the second
  # would enter Nim code the first had not finished initializing. The platform
  # primitives block the losers until the winner returns, which a flag cannot.
  #
  # C statics, not Nim globals: module initialization would reset a Nim one and
  # NimMain would run again. NimMain is declared here too — the generated
  # prototype comes after this section.
  {.emit: """/*VARSECTION*/
void NimMain(void);
#ifdef _WIN32
#  include <windows.h>
static INIT_ONCE unimcp_runtime_once = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK unimcp_runtime_init(PINIT_ONCE o, PVOID p, PVOID *c) {
  (void)o; (void)p; (void)c; NimMain(); return TRUE;
}
static void unimcp_runtime_ensure(void) {
  InitOnceExecuteOnce(&unimcp_runtime_once, unimcp_runtime_init, NULL, NULL);
}
#else
#  include <pthread.h>
static pthread_once_t unimcp_runtime_once = PTHREAD_ONCE_INIT;
static void unimcp_runtime_init(void) { NimMain(); }
static void unimcp_runtime_ensure(void) {
  pthread_once(&unimcp_runtime_once, unimcp_runtime_init);
}
#endif
""".}
  template ensureRuntime() =
    {.emit: "  unimcp_runtime_ensure();".}
else:
  template ensureRuntime() = discard

type
  ToolCallback = proc(name, arguments: cstring; userData: pointer): cstring {.
    cdecl, gcsafe, raises: [].}
    ## What C passes for `tools/call`. Returns the tool's structured result as
    ## a JSON object, or NULL to report the call as failed.

  AbiServer = ref object
    ## The handle a C caller holds: a ref, pinned across the boundary so ARC
    ## does not collect what only C still points at.
    server: Server
    response: string
      ## Owns the string the last `unimcp_server_handle` returned. Keeping it
      ## on the handle is what makes that pointer valid until the next call,
      ## and no longer -- a Nim temporary would be freed before C reads it.

# The reason for the last failure, read back through `unimcp_last_error`.
# A single slot, as the header states: it is overwritten by the next failure.
var lastError = ""

proc setError(message: string) {.raises: [].} =
  lastError = message

proc currentMessage(fallback: string): string {.raises: [].} =
  ## The message of the exception being handled, or `fallback` for a Defect,
  ## which carries none worth reporting across the ABI.
  let error = getCurrentException()
  if error == nil or error.msg.len == 0: fallback else: error.msg

proc field(node: JsonNode; key: string): string =
  ## A string member, or "" when absent -- the descriptor's optional prose.
  if node.hasKey(key) and node[key].kind == JString: node[key].getStr else: ""

proc flag(node: JsonNode; key: string): bool =
  if node.hasKey(key) and node[key].kind == JBool: node[key].getBool else: false

proc descriptors(tools: JsonNode): seq[ToolDescriptor] =
  ## Tool descriptors from the JSON array a caller supplies. Anything the
  ## engine would reject -- a missing name, a schema that is not an object --
  ## is left to `newServer`, which already states those rules once.
  if tools.kind != JArray:
    raise newException(ValueError, "tools must be a JSON array")
  for entry in tools:
    if entry.kind != JObject:
      raise newException(ValueError, "each tool must be a JSON object")
    result.add tool(entry.field("name"), entry.field("title"),
      entry.field("description"),
      if entry.hasKey("inputSchema"): entry["inputSchema"] else: newJNull(),
      entry.flag("readOnlyHint"), entry.flag("destructiveHint"),
      entry.flag("idempotentHint"), entry.flag("openWorldHint"))

proc protocols(info: JsonNode): seq[string] =
  if not info.hasKey("supportedProtocols") or
      info["supportedProtocols"].kind != JArray:
    raise newException(ValueError, "supportedProtocols must be a JSON array")
  for entry in info["supportedProtocols"]:
    if entry.kind != JString:
      raise newException(ValueError, "supportedProtocols must hold strings")
    result.add entry.getStr

proc dispatcher(handler: ToolCallback; userData: pointer): ToolHandler =
  ## The engine's tool handler, closing over the C callback. Built outside the
  ## exported block below: a pragma push reaches nested procs, and an anonymous
  ## one cannot carry the `exportc` that `dynlib` requires.
  ##
  ## The callback answers with the structured content; NULL is how C reports
  ## the call failed, and RpcError is what the engine turns into an error
  ## result rather than a dead server.
  result = proc(name: string; arguments: JsonNode): JsonNode =
    let answer = handler(name.cstring, ($arguments).cstring, userData)
    if answer == nil:
      raise newException(RpcError, "tool call failed: " & name)
    toolResult(parseJson($answer))

{.push exportc, cdecl, dynlib, raises: [].}

proc unimcp_version(): cstring =
  ## Static version string; do not free.
  ensureRuntime()
  UniMCPVersionC

proc unimcp_abi_version(): cint =
  ## C ABI generation. A consumer built against another one is not compatible.
  ensureRuntime()
  UniMCPAbiVersion

proc unimcp_last_error(): cstring =
  ## The message for the failure the last call reported, or "" when none has.
  ## Borrowed: this library owns it, and the next failing call overwrites it.
  ensureRuntime()
  lastError.cstring

proc unimcp_server_new(info: cstring; tools: cstring; handler: ToolCallback;
    userData: pointer): pointer =
  ## A server from its JSON description, or NULL with the reason in
  ## `unimcp_last_error`. Free with `unimcp_server_free`.
  ensureRuntime()
  if info == nil or tools == nil or handler == nil:
    setError("unimcp_server_new: NULL argument")
    return nil
  try:
    let described = parseJson($info)
    if described.kind != JObject:
      raise newException(ValueError, "info must be a JSON object")
    let handle = AbiServer(server: newServer(
      ServerInfo(name: described.field("name"), title: described.field("title"),
        version: described.field("version"),
        description: described.field("description")),
      described.field("latestProtocol"), described.protocols,
      parseJson($tools).descriptors, dispatcher(handler, userData),
      described.field("instructions")))
    # Pinned: the C caller holds the only reference, and ARC would collect it
    # the moment this proc returns.
    GC_ref(handle)
    cast[pointer](handle)
  except CatchableError, Defect:
    setError(currentMessage("unimcp_server_new failed"))
    nil

proc unimcp_server_free(handle: pointer) =
  ## Release a server. NULL is a no-op; freeing twice is not (the caller owns
  ## the handle and must not present it again).
  ensureRuntime()
  if handle == nil: return
  GC_unref(cast[AbiServer](handle))

proc unimcp_server_handle(handle: pointer; line: cstring): cstring =
  ## The reply to one JSON-RPC message, "" for a notification, or NULL with the
  ## reason in `unimcp_last_error`. Borrowed: valid until the next call on this
  ## same server.
  ensureRuntime()
  if handle == nil or line == nil:
    setError("unimcp_server_handle: NULL argument")
    return nil
  let server = cast[AbiServer](handle)
  try:
    server.response = server.server.handleLine($line)
    server.response.cstring
  # `Exception`, not the usual `CatchableError, Defect` pair: the tool handler
  # is a closure the engine calls, so its effect is inferred as bare
  # `Exception`, which is neither of those and would escape a narrower clause.
  except Exception:
    setError(currentMessage("unimcp_server_handle failed"))
    nil

{.pop.}
