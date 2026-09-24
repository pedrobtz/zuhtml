/* A minimal stand-in for libFuzzer where its runtime is unavailable (Apple
 * clang ships none). Usage: <target> <seconds> <corpus files...>. Runs
 * each file, then random mutations of them, through
 * LLVMFuzzerTestOneInput until the time is up. Crashes surface through the
 * sanitizers it is built with. Deterministic seed. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

static unsigned long rng = 88172645463325252UL;

static unsigned long
next_rand(void) {
  rng ^= rng << 13;
  rng ^= rng >> 7;
  rng ^= rng << 17;
  return rng;
}

int
main(int argc, char **argv) {
  double secs = argc > 1 ? atof(argv[1]) : 10;
  uint8_t **seeds = (uint8_t **) malloc((size_t) argc * sizeof(uint8_t *));
  size_t *lens = (size_t *) malloc((size_t) argc * sizeof(size_t));
  int n = 0, i;
  unsigned long runs = 0;
  clock_t end;
  /* Bytes that matter to both HTML and CSS. */
  static const char dict[] =
      "<>/=\"'&;#!-?.[]~|^$*:() ,+_\\\n\tpdivlitrabsxg0123456789\xc2\xa0";

  if (seeds == NULL || lens == NULL)
    return 2;
  for (i = 2; i < argc; i++) {
    FILE *f = fopen(argv[i], "rb");
    long len;
    if (f == NULL)
      continue;
    fseek(f, 0, SEEK_END);
    len = ftell(f);
    fseek(f, 0, SEEK_SET);
    seeds[n] = (uint8_t *) malloc((size_t) len + 1);
    lens[n] = fread(seeds[n], 1, (size_t) len, f);
    fclose(f);
    LLVMFuzzerTestOneInput(seeds[n], lens[n]);
    n++;
  }
  if (n == 0) {
    seeds[0] = (uint8_t *) strdup("p");
    lens[0] = 1;
    n = 1;
  }
  end = clock() + (clock_t) (secs * CLOCKS_PER_SEC);
  while (clock() < end) {
    int s = (int) (next_rand() % (unsigned long) n);
    size_t len = lens[s], k, edits = 1 + next_rand() % 4;
    uint8_t buf[2048];
    if (len > sizeof(buf) - 8)
      len = sizeof(buf) - 8;
    memcpy(buf, seeds[s], len);
    for (k = 0; k < edits; k++) {
      size_t at = len ? next_rand() % (len + 1) : 0;
      switch (next_rand() % 4) {
      case 0: /* insert */
        if (len < sizeof(buf) - 1) {
          memmove(buf + at + 1, buf + at, len - at);
          buf[at] = (uint8_t) dict[next_rand() % (sizeof(dict) - 1)];
          len++;
        }
        break;
      case 1: /* delete */
        if (len > 0 && at < len) {
          memmove(buf + at, buf + at + 1, len - at - 1);
          len--;
        }
        break;
      case 2: /* replace with a dictionary byte */
        if (at < len)
          buf[at] = (uint8_t) dict[next_rand() % (sizeof(dict) - 1)];
        break;
      default: /* replace with any byte */
        if (at < len)
          buf[at] = (uint8_t) next_rand();
      }
    }
    LLVMFuzzerTestOneInput(buf, len);
    runs++;
  }
  printf("standalone: %lu runs over %d seeds\n", runs, n);
  return 0;
}
