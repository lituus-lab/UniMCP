# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, osproc, strutils]
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "The C surface"

const Root = currentSourcePath().parentDir.parentDir

proc run(command: string): string =
  ## Run a command from the repository root and return its output. Used so the
  ## results on this page are produced rather than transcribed.
  ##
  ## A non-zero exit stops the book. Returning the failure as text instead
  ## would publish a page whose "output" is a traceback, from a build that
  ## reported success.
  let (output, code) = execCmdEx("cd " & Root.quoteShell & " && " & command)
  result = output.strip
  if code != 0:
    raise newException(OSError,
      "book: `" & command & "` exited " & $code & "\n" & result)

nbText: """
# The C surface

Two JSON documents and one function pointer. That is the whole ABI: nothing
about a Nim type reaches C, so a caller in any language that can produce JSON
and pass a function pointer can drive an MCP server.

```c
void *unimcp_server_new(const char *info, const char *tools,
                        unimcp_tool_handler handler, void *user_data);
const char *unimcp_server_handle(void *server, const char *line);
void  unimcp_server_free(void *server);
const char *unimcp_last_error(void);
```

The handler goes the other way — UniMCP calls **you**:

```c
typedef const char *(*unimcp_tool_handler)(const char *name,
                                           const char *arguments,
                                           void *user_data);
```

Return the tool's structured result as JSON, or `NULL` to report the call as
failed. `user_data` is whatever you handed to `unimcp_server_new`, which is how
a C program without closures gets its context back.

## Three rules about memory

- **The reply is borrowed.** `unimcp_server_handle` returns a pointer the
  server owns, valid until the next call on that same server. Copy it to keep
  it.
- **Your answer is copied.** The string the handler returns is read before that
  call returns, so a `static` buffer is enough.
- **The handle is yours to free.** `unimcp_server_free` once, and `NULL` is a
  documented no-op — freeing twice is not.

## Failure, told twice

Two different failures reach a C caller through two different channels, and
conflating them is the mistake this ABI is shaped to prevent:

| What went wrong | How you learn |
|---|---|
| the call could not be made (NULL argument, bad description) | `NULL` return, reason in `unimcp_last_error` |
| the *protocol* rejected the message | a normal reply carrying an error object |
| a *tool* failed | a normal reply with `"isError": true` |

Only the first is an ABI failure. The other two are answers, and a server that
treats them as errors will hang up on clients that are behaving correctly.

## Driven from C

`examples/c/demo.c` builds the same server this book opened with, and is
compiled and run here.
"""

nbCode:
  echo run("cc -Iinclude -o build/book_c_demo examples/c/demo.c libUniMCP.a" &
          " && ./build/book_c_demo")

nbText: """
No Nim runtime call appears in that program, and none is needed: every entry
point initializes the runtime itself, once, through a platform once-primitive.
That matters because the library is built `--noMain`, which suppresses the
constructor a shared library would otherwise get — without that guard the first
call would run against globals nobody had set up.

## Versions

`unimcp_version()` is the library's; `unimcp_abi_version()` is the ABI's
generation, and `UNIMCP_ABI_VERSION` in the header is what you compiled
against. Compare them at startup if you load the library dynamically — they
disagreeing is exactly the incompatibility the generation exists to announce.
"""

nbSave
