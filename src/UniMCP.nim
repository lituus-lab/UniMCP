# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniMCP — umbrella module. Re-exports every public submodule.
##
## `std/json` is re-exported with them: every public procedure here takes or
## returns a `JsonNode`, so a caller that imports UniMCP alone cannot build a
## request or read a result. Re-exporting it is what makes `import UniMCP` a
## complete import rather than the first of two.
import std/json
import UniMCP/[types, server]
export json, types, server

const UniMCPVersion* = "0.1.0"
