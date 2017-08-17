#!/bin/bash
# Runs mst

POWER_PROFILING=0
SAMPLING=0
if [ "$POWER_PROFILING" = '1' -a $(whoami) != 'root' ]; then
	echo "You must be root to run power measurement"
	exit 2
fi
# Load options
module load tau
export DDIR=/home/users/spollard/graphalytics/all-datasets/PBBSInput
# You can see other native metrics using papi_avail and papi_native_avail
export TAU_METRICS="TIME,PAPI_TOT_INS,PAPI_TOT_CYC,PAPI_NATIVE_rapl:::PACKAGE_ENERGY:PACKAGE0"
export OMP_NUM_THREADS=8
S=20
N_VERT=$(echo 2 ^ $S | bc)
RT=ER
CVERTS=5000
EPV=8
INS_PCT=90
FULL_SUFFIX="${S}${EPV}_${RT}_${INS_PCT}i_${CVERTS}"
PART_SUFFIX="${S}${EPV}_${RT}"
XPS_DIR="/home/users/spollard/easy-parallel-graph/autoperf/mst/lib/xpscode/MSTSC"

# Build the executable normally (sampling) or with taucc (instrumentation)
if [ "$SAMPLING" = "0" ]; then
	CXX="taucxx -tau:headerinst"
	CC="taucc -tau:headerinst"
else
	CXX="g++"
	CC="gcc"
fi
export TAU_MAKEFILE="$TAU_DIR/x86_64/lib/Makefile.tau-papi-ompt-openmp"
cd $XPS_DIR
if [ "$POWER_PROFILING" = "1" ]; then
	RAPL_DIR="$HOME/easy-parallel-graph/power"
	POWER_CFLAGS="-I$PAPI/include -I$RAPL_DIR -DPOWER_PROFILING=1"
	RAPL_INC="power_rapl.o $RAPL_DIR/power_rapl.h -L$PAPI/lib -Wl,-rpath,$PAPI/lib -lpapi"
	$CC -c $POWER_CFLAGS "$RAPL_DIR/power_rapl.c" -o "$XPS_DIR/power_rapl.o"
	make CXX="$CXX" CFLAGS="$POWER_CFLAGS" RAPL_INC="$RAPL_INC" all # This only builds the mst update executable (a.out)
else
	make CXX="$CXX" all
fi
# These are just for preparing the data so don't need anything fancy.
make cE
make tEx
make bfs

###
# Sampling
###
# This must be run as root.
if [ "$SAMPLING" = '1' ]; then
	tau_exec -T papi,openmp -ebs "$XPS_DIR/a.out" "$DDIR/rmat${PART_SUFFIX}.diff" "$DDIR/rmat${PART_SUFFIX}.cert" "$DDIR/changedrmat${FULL_SUFFIX}S" 100 $N_VERT $OMP_NUM_THREADS
###
# Instrumentation
###
else
	"$XPS_DIR/a.out" "$DDIR/rmat${PART_SUFFIX}.diff" "$DDIR/rmat${PART_SUFFIX}.cert" "$DDIR/changedrmat${FULL_SUFFIX}S" 100 $N_VERT $OMP_NUM_THREADS
fi
chown -R spollard MULTI__*

# May want to "keep unresolved"
# Verbose may be useful
# -tau:makefile <file> Specify TAU stub Makefile
# TODO: Must convert from their nanojoules to joules: (* 1e-9)
# TODO: no -pdt in makefile? Should it be there or not?

# Then analyze with paraprof or pprof

