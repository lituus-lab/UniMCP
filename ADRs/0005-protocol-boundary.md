<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0005: what UniMCP implements of MCP, and what it does not

- Status: Accepted
- Date: 2026-09-03
- Scope: UniMCP

## Context

MCP specifies more than a server has to offer: tools, prompts, resources,
sampling, roots. A library can advertise a capability and implement it
partially — the protocol has no way to say "half".

## Decision

UniMCP implements the JSON-RPC lifecycle and the **tool** surface, and
advertises nothing else. Prompts and resources stay out until there is a
consumer to test against and fixtures to conform to.

Transport is one JSON message per line, over stdio. Protocol versions
`2025-11-25` and `2024-11-05` are negotiated; an unknown one is answered with
the server's own latest rather than refused.

## Consequences

- A client that needs prompts or resources cannot use UniMCP, and finds that
  out from `initialize` rather than from a call that half-works.
- The lifecycle is enforced: before `notifications/initialized`, everything but
  `initialize` and `ping` is refused with `-32002`. A client that skips the
  handshake gets an error, not a best effort.
- Adding a capability later is additive for clients that already work — they
  negotiate the same versions and see one more capability, not a changed one.
- The 4 MiB line limit is a transport decision, not a message one: it bounds
  what a peer can make the server allocate before anything is parsed.
