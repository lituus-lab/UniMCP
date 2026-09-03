# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
cdef extern from "UniMCP.h":
    const char *unimcp_version()
    long long unimcp_fibonacci(int n)
    # The domain bound comes from the header rather than being restated here:
    # one copy fewer to drift, and the Python check enforces exactly what the
    # C ABI clamps to.
    int UNIMCP_FIB_MAX_N


FIB_MAX_N = UNIMCP_FIB_MAX_N


def fibonacci(int n):
    """Raw C call (no domain check). Use unimcp.fibonacci."""
    return unimcp_fibonacci(n)


def version():
    return unimcp_version()
