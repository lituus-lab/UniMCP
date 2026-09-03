# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Every suite in one binary. Coverage instruments a single compilation, so a
## second one into the same nimcache would overwrite the first one's data and
## report whichever ran last.
import ./test_protocol
import ./test_dispatch
import ./test_version
