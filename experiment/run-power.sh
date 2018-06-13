#!/bin/bash
# Measure Power Usage and Energy Consumption
# Just works for BFS on Graph500, GraphMat, and GAP
# Requires root, PAPI, and the intel compiler.
# NOTE: Before you run this, make sure the parameters are set corrrectly

# Set some parameters and environment variables
# CHECK THAT THESE ARE CORRECT ON YOUR OWN SYSTEM!
# NOTE: on Arya, graph500, GraphBIG, and GAP must be recompiled.
USAGE="usage: sudo -E run-power.sh [--libdir=<dir>] [--ddir=<dir>] <scale> <num-threads>
	--libdir: repositories directory. Default: ./powerlib
	--ddir: dataset directory. Default: ./datasets" # 2^{<scale>} = Number of vertices.
DDIR="$(pwd)/datasets" # Dataset directory
LIBDIR="$(pwd)/powerlib"
for arg in "$@"; do
	case $arg in
	--libdir=*)
		LIBDIR=${arg#*=}
		shift
	;;
	--ddir=*)
		DDIR=${arg#*=}
		shift
	;;
	-h|--help|-help)
		echo "$USAGE"
		exit 2
	;;
	*)	# Default
		# Do nothing
	esac
done
if [ "$#" -lt 2 ]; then
	echo 'Please provide <scale> and <num_threads>'
	echo $USAGE
	exit 2
fi
env | grep -q "PAPI"
if [ "$?" -ne 0 ];
	echo "Please ensure PAPI environment variable is set"
	exit 1
fi
# Set parameters based on commmand line
S=$1
export OMP_NUM_THREADS=$2
GAPDIR="$LIBDIR/gapbs"
GRAPHBIGDIR="$LIBDIR/graphBIG"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
POWERGRAPHDIR="$LIBDIR/PowerGraph"

# Set other parameters and load computer-specific modules
NRT=32 # Number of roots that we did BFS on. GraphBIG has issues with >32.
PKG=2 # The number of physical chips

# Set variables used by the script
export SKIP_VALIDATION=1 # Graph500 by default verifies the BFS
T=$OMP_NUM_THREADS
FN="powerout/out${S}-${T}-power.log"
ERRFN="powerout/out${S}-${T}-power.err"
PFN="powerout/parsed${S}-${T}-power.csv"

# Run experiments
# Graph500 BFS
"$GRAPH500DIR/omp-csr/omp-csr" -s $S > "$FN" 2> "$ERRFN"
# GAP BFS
for ROOT in $(head -n $NRT "$DDIR/kron-${S}/kron-${S}-roots.v"); do
	sudo -E "$GAPDIR"/bfs -r $ROOT -f "$DDIR/kron-${S}/kron-${S}.el" -n 1 -s
done >> "$FN" 2>> "$ERRFN"
# GraphMat BFS
for ROOT in $(head -n $NRT "$DDIR/kron-${S}/kron-${S}-roots.1v"); do
	echo "BFS root: $ROOT"
	# WARNING: May not behave nicely if there are spaces in your DDIR, LD, or GRAPHMATDIR paths
	bash -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; $GRAPHMATDIR/bin/BFS $DDIR/kron-${S}/kron-${S}.graphmat $ROOT"
	#"$GRAPHMATDIR/bin/BFS" "$DDIR/kron-${S}.graphmat" "$ROOT"
done >> "$FN" 2>> "$ERRFN"
# GraphBIG BFS
head -n $NRT "$DDIR/kron-${S}/kron-${S}-roots.v" > "$DDIR/kron-${S}/kron-${S}-${NRT}roots.v"
"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/kron-${S}" --rootfile "$DDIR/kron-${S}/kron-${S}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS >> "$FN" 2>> "$ERRFN"

# Baseline (do nothing, just sleep)
"$GAPDIR"/sleep_baseline >> "$FN" 2>> "$ERRFN"
chown $USER "$FN"
chown $USER "$ERRFN"

# CPU
# CPU Average Power and CPU Total Energy
# We sum across all packages, and a package is one physical chip.
# XXX: -A 29 will only work if you have <= 2 packages
# GAP
grep -A 29 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GAP,BFS,Average CPU Power (W)," t;t=0}else{t+=$3}}' > "$PFN"
grep -A 29 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GAP,BFS,Total CPU Energy (J)," t;t=0}else{t+=$3}}' >> "$PFN"
# Graph500
grep -A 29 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Graph500,BFS,Total CPU Energy (J)," t;t=0}else{t+=$3}}' >> "$PFN"
grep -A 29 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Graph500,BFS,Average CPU Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
# GraphMat
grep -A 29 'RAPL on GraphMat BFS' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphMat,BFS,Average CPU Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
grep -A 29 'RAPL on GraphMat BFS' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphMat,BFS,Total CPU Energy (J)," t;t=0}else{t+=$3}}' >> "$PFN"
# GraphBIG
grep -A 31 'RAPL on GraphBIG BFS' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphBIG,BFS,Average CPU Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
grep -A 31 'RAPL on GraphBIG BFS' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphBIG,BFS,Total CPU Energy (J)," t;t=0}else{t+=$3}}' >> "$PFN"
# Baseline
grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Baseline,Sleep,Average CPU Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Baseline,Sleep,Total CPU Energy (J)," t;t=0}else{t+=$3}}' >> "$PFN"

# RAM
# DRAM Average Power
# We sum across all packages--all the DIMMs associated with one physical chip
# GAP
grep -A 31 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GAP,BFS,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
# Graph500
grep -A 31 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Graph500,BFS,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
# GraphMat
grep -A 31 'RAPL on GraphMat BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphMat,BFS,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
# GraphBIG
grep -A 31 'RAPL on GraphBIG BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphBIG,BFS,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
# Baseline
grep -A 31 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Baseline,Sleep,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"

# Timings
# GAP
grep -A 31 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GAP,BFS,RAPL Time (s)," t;t=0}else{t+=$1}}' >> "$PFN"
# Graph500
grep -A 31 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Graph500,BFS,RAPL Time (s)," t;t=0}else{t+=$1}}' >> "$PFN"
# GraphMat
grep -A 31 'RAPL on GraphMat BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphMat,BFS,RAPL Time (s)," t;t=0}else{t+=$1}}' >> "$PFN"
# GraphBIG
grep -A 31 'RAPL on GraphBIG BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphBIG,BFS,RAPL Time (s)," t;t=0}else{t+=$1}}' >> "$PFN"
# Baseline
grep -A 31 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Baseline,Sleep,RAPL Time (s)," t;t=0}else{t+=$1}}' >> "$PFN"

chown $USER "$PFN"

