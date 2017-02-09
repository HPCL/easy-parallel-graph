/** 
 * @author Boyana Norris
 */
#ifndef POWER_RAPL_H
#define POWER_RAPL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "papi.h"

#define MAX_RAPL_EVENTS 128

typedef struct {
  char events[MAX_RAPL_EVENTS][BUFSIZ];
  char filenames[MAX_RAPL_EVENTS][BUFSIZ];
  FILE *fff[MAX_RAPL_EVENTS];
  int numcmp;
  int EventSet;
  long long values[MAX_RAPL_EVENTS];
  long long start_time;
  long long before_time;
  double total_time;
  double elapsed_time;
  int num_events;
} power_rapl_t; 

void power_rapl_init(power_rapl_t *);
void power_rapl_start(power_rapl_t *);
void power_rapl_end(power_rapl_t *);
void power_rapl_print(power_rapl_t *);

#ifdef __cplusplus
} /* extern C */
#endif

#endif
