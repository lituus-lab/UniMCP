<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Changelog

Notable changes, newest first. Format after
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The C ABI has its own compatibility: a symbol removed or retyped is a major
change, whatever the Nim API did.

## [Unreleased]

Nothing released yet; 0.1.0 will be the first tag. What it will carry:

### Added

- The MCP server engine: JSON-RPC 2.0 framing, the `initialize` /
  `notifications/initialized` lifecycle, protocol negotiation over
  `2025-11-25` and `2024-11-05`, a tool registry with MCP's annotation hints,
  dispatch, and the protocol's error codes.
- `serveStdio`, and `handleLine` under it for callers that own their own loop.
- A C ABI over the same engine: a server is two JSON documents and a tool
  callback, and every message crosses as a NUL-terminated string. Failures are
  a NULL return with the reason in `unimcp_last_error`; no Nim exception
  crosses the boundary.
- A Cython binding, `unimcp.Server`, dispatching into a Python callable.
  Distributed as `lituus-unimcp`, imported as `unimcp`.
- A six-chapter book whose C and Python chapters compile and run the demos
  they document, and a quickstart notebook executed against the wheel.
- The family's gates: `tools/gate.nim` and a success marker per task, a
  `canary` that must fail, `all-green` over every CI job, `tests/test_version.nim`
  for the version's copies and the ABI generation's two.

### Known limits

- Tools are the only MCP capability advertised. Prompts and resources are out
  of scope until there is a consumer to test against — see ADR-0005.
- The `0.x` C ABI is not frozen.
