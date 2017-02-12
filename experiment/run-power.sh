#!/bin/bash
# Measure Power Usage and Energy Consumption
# Just works for BFS on Graph500, GraphMat, and GAP
# Requires root, PAPI, and the intel compiler.
# NOTE: Before you run this, make sure the parameters are set corrrectly
# usage: ./run-power.sh

# Set some parameters and environment variables
# CHECK THAT THESE ARE CORRECT ON YOUR OWN SYSTEM!
module load intel/17
module load papi/git
DDIR= # Dataset directory
GAPDIR=
GRAPH500DIR=
GRAPHMATDIR=
S=16
NRT=32 # Number of roots that we did BFS on. GraphBIG has issues with >32.
PKG=2 # The number of physical chips
export OMP_NUM_THREADS=32

# Set variables used by the script
export SKIP_VALIDATION=1 # Graph500 by default verifies the BFS
T=$OMP_NUM_THREADS
FN="out${S}-${T}-power.log"
ERRFN="out${S}-${T}-power.err"
PFN="parsed${S}-${T}-power.csv"

# Run experiments
# GAP BFS
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
	sudo "$GAPDIR"/bfs -r $ROOT -f "$DDIR/kron-${S}.el" -n 1 -s
done > "$FN" 2> "$ERRFN"
# Graph500 BFS
sudo "$GRAPH500DIR/omp-csr/omp-csr" -s $S >> "$FN" 2>> "$ERRFN"
# GraphMat BFS
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.1v"); do
	echo "BFS root: $ROOT"
	# WARNING: May not behave nicely if there are spaces in your DDIR, LD, or GRAPHMATDIR paths
	sudo bash -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; $GRAPHMATDIR/bin/BFS $DDIR/kron-${S}.graphmat $ROOT"
	#"$GRAPHMATDIR/bin/BFS" "$DDIR/kron-${S}.graphmat" "$ROOT"
done >> "$FN" 2>> "$ERRFN"
# Baseline (do nothing, just sleep)
sudo "$GAPDIR"/sleep_baseline >> "$FN" 2>> "$ERRFN"
sudo chown spollard "$FN"
sudo chown spollard "$ERRFN"

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
# Baseline
grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Baseline,Sleep,Average CPU Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Baseline,Sleep,Total CPU Energy (J)," t;t=0}else{t+=$3}}' >> "$PFN"

# RAM
# DRAM Average Power
# We sum across all packages--all the DIMMs associated with one physical chip
grep -A 31 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GAP,BFS,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
# Graph500
grep -A 31 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Graph500,BFS,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
# GraphMat
grep -A 31 'RAPL on GraphMat BFS' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "GraphMat,BFS,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"
# Baseline
grep -A 31 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*DRAM_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){print "Baseline,Sleep,Average DRAM Power (W)," t;t=0}else{t+=$3}}' >> "$PFN"

sudo chown spollard "$PFN"

