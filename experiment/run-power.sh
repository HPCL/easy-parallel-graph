#!/bin/bash
# Measure Power Consumption
# Just works for BFS on Graph500 and GAP
# Requires root

# Set some parameters and environment variables
module load intel/17
module load tau
DDIR= # Dataset directory
GAPDIR=
GRAPH500DIR=
GRAPHMATDIR=
S=23
NRT=32 # Number of roots that we did BFS on. GraphBIG has issues with >32.
PKG=2 # The number of physical chips
export OMP_NUM_THREADS=32
export SKIP_VALIDATION=1 # Graph500 by default verifies the BFS
T=$OMP_NUM_THREADS
FN="out${S}-${T}-power.log"
PFN="parsed${S}-${T}-power.csv"

# Run experiments
# GAP BFS
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
    "$GAPDIR"/bfs -r $ROOT -f "$DDIR/kron-${S}.el" -n 1 -s
done > "$FN" 2> out${S}-${T}-power.err
# Graph500 BFS
"$GRAPH500DIR/omp-csr/omp-csr" -s $S >> "$FN" 2>> "out${S}-${T}-power.err"
# GraphMat BFS
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.1v"); do
	echo "BFS root: $ROOT"
    # WARNING: May not behave nicely if there are spaces in your DDIR or LD path
    # TODO: Check if this is actually running on 32 threads
    bash -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; "$GRAPHMATDIR/bin/BFS" $DDIR/kron-${S}.graphmat $ROOT"
done > "$FN" 2> out${S}-${T}-power.err
# Baseline (do nothing, just sleep)
"$GAPDIR"/sleep_baseline >> "$FN" 2>> "out${S}-${T}-power.err"
chown spollard "$FN"
chown spollard "out${S}-${T}-power.err"

# Parse
# CPU Average Power
grep -A 29 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GAP,BFS,Average CPU Power (W)," t/PKG;t=0}else{t+=$3}}' > "$PFN"
grep -A 29 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Graph500,BFS,Average CPU Power (W)," t/PKG;t=0}else{t+=$3}}' >> "$PFN"
# CPU Total Energy
grep -A 29 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GAP,BFS,Total CPU Energy (J)," t/PKG;t=0}else{t+=$3}}' >> "$PFN"
grep -A 29 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Graph500,BFS,Total CPU Energy (J)," t/PKG;t=0}else{t+=$3}}' >> "$PFN"
# Baseline Power
grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{t+=$3;c++}END{print "NONE,Sleep,Average CPU Power (W)," t/(c*PKG)}' >> "$PFN"
grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{s+=$1;t+=$3;c++}END{print "NONE,Sleep,Total CPU Energy (J)," (s*t)/(c*PKG)}' >> "$PFN"

chown spollard "$PFN"

