/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
/* Run by book/surfaces.nim during the book build; its output is the page's. */
#include <stdio.h>
#include "UniMCP.h"

int main(void) {
  printf("unimcp_version()            = %s\n", unimcp_version());
  printf("unimcp_fibonacci(10)        = %lld\n", unimcp_fibonacci(10));
  printf("unimcp_fibonacci(-1)        = %lld   (clamped, not an error)\n",
         unimcp_fibonacci(-1));
  printf("unimcp_fibonacci(200)       = %lld   (clamped to n = %d)\n",
         unimcp_fibonacci(200), UNIMCP_FIB_MAX_N);
  return 0;
}
