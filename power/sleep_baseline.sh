#!/bin/bash
# Runs and parses the sleep baseline for multiple thread counts (and serial)
# Must have PAPI_HOME set (by installing PAPI)

PKG=2 # The number of physical CPU sockets
THREADS="1 2 4 8 16 24 32 40 48 56 64 72"
FN=sleep_baseline.out
PFN=parsed_sleep_baseline.csv
NUM_TRIALS=16

# Run serial:
CFLAGS="-I${PAPI_HOME}/include -DPOWER_PROFILING=1 -g -Wall"
LDLIBS="-L${PAPI_HOME}/lib -Wl,-rpath,${PAPI_HOME}/lib -lpapi -lm"
cc $CFLAGS -c -o power_rapl.o power_rapl.c $LDLIBS
cc $CFLAGS -c -o sleep_baseline.o sleep_baseline.c
cc $CFLAGS -o sleep_baseline sleep_baseline.o power_rapl.o $LDLIBS
echo "Running serial sleep..."
echo "package,algorithm,threads,measurement,value" > "$PFN"

for TRIAL in $(seq $NUM_TRIALS); do
	./sleep_baseline > "$FN"
	grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "No OpenMP,Sleep,'1',Average CPU Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
	grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "No OpenMP,Sleep,'1',Total CPU Energy (J)," t;t=0}else{t+=$3}}' >> "$PFN"
done

# Run parallel (if compiling on icpc use -openmp)
# Even though we still run serial, recompiling for openmp using 1 thread may be different
CFLAGS="$CFLAGS -fopenmp"
cc $CFLAGS -c -o power_rapl.o power_rapl.c $LDLIBS
cc $CFLAGS -c -o sleep_baseline.o sleep_baseline.c
cc $CFLAGS -o sleep_baseline sleep_baseline.o power_rapl.o $LDLIBS

echo "Running sleep with OpenMP threads:"
for T in $(echo $THREADS); do
	echo -n "$T "
	export OMP_NUM_THREADS=$T
	for TRIAL in $(seq $NUM_TRIALS); do
		./sleep_baseline > "$FN"
		grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "OpenMP,Sleep,'$T',Average CPU Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
		grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "OpenMP,Sleep,'$T',Total CPU Energy (J)," t;t=0}else{t+=$3}}' >> "$PFN"
	done
done
echo "Results saved to $PFN"

