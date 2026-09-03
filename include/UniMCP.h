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

/* Largest n with unimcp_fibonacci(n) fitting in long long (int64). */
#define UNIMCP_FIB_MAX_N 92

/* Static version string; do not free. */
const char *unimcp_version(void);

/* fibonacci(n), n clamped to [0, UNIMCP_FIB_MAX_N].
 * n < 0 -> 0; n > UNIMCP_FIB_MAX_N -> fibonacci(UNIMCP_FIB_MAX_N).
 * Never raises. Single-threaded, reentrant. */
long long unimcp_fibonacci(int n);

#ifdef __cplusplus
}
#endif

#endif /* UNIMCP_H */
