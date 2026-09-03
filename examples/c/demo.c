// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include <stdio.h>
#include "UniMCP.h"

int main(void) {
  printf("UniMCP %s\n", unimcp_version());
  int ns[] = {0, 1, 10, 20, 50, 90, UNIMCP_FIB_MAX_N};
  for (size_t i = 0; i < sizeof(ns) / sizeof(ns[0]); i++)
    printf("fib(%d) = %lld\n", ns[i], unimcp_fibonacci(ns[i]));
  return 0;
}
