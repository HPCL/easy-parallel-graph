# Using RAPL
You must modify your Makefile to get power monitoring. An example is shown below and consists of building the object file, then linking it in to your main executable. You must have PAPI installed and set the `PAPI_HOME`  variable accordingly.

The executable must be run as root.

```
PAPI_HOME=/usr/local/packages/papi/git
CFLAGS = -I$(PAPI_HOME)/include -g -Wall -DPOWER_PROFILING=1
LDLIBS = -L$(PAPI_HOME)/lib -Wl,-rpath,$(PAPI_HOME)/lib -lpapi -lm
power_rapl.o : power_rapl.c power_rapl.h
	$(CC) $(CFLAGS) -c -o power_rapl.o power_rapl.c $(LDLIBS)
sleep_baseline: power_rapl.o
	$(CC) $(CFLAGS) -c -o sleep_baseline.o sleep_baseline.c
	$(CC) $(CFLAGS) -o sleep_baseline sleep_baseline.o power_rapl.o $(LDLIBS)
profiled_target: power_rapl.o
	$(CC) $(CFLAGS) -o profiled_target <other objects> power_rapl.o $(LDLIBS)
```

Then put something like this inside your source code. This will work with C or C++.
```
#ifdef POWER_PROFILING
#include "power_rapl.h"
#endif

...

#ifdef POWER_PROFILING
  power_rapl_t ps;
  power_rapl_init(&ps);
  printf("Monitoring power with RAPL\n");
#endif

#ifdef POWER_PROFILING
    power_rapl_start(&ps);
#endif

<code you want to profile>

#ifdef POWER_PROFILING
    power_rapl_end(&ps);
    power_rapl_print(&ps);
#endif
```

This code was taken from Boyana Norris (brnorris03).

