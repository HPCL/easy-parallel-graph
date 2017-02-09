#!/bin/bash
# Measure Power Consumption
# Just works for BFS on Graph500 and GAP
# Requires root

# Set some parameters
DDIR=/home/users/spollard/graphalytics/all-datasets/gabb17 # Dataset directory
GAPDIR=/home/users/spollard/gap/gapbs
GRAPH500DIR=/home/users/spollard/graph500
S=23
NRT=32 # Number of roots that we did BFS on. GraphBIG has issues with >32.
PKG=2 # The number of physical chips
export OMP_NUM_THREADS=32
T=$OMP_NUM_THREADS
FN="out${S}-${T}-power.log"
PFN="parsed${S}-${T}-power.csv"

# Run experiments
# GAP BFS
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
    sudo "$GAPDIR"/bfs -r $ROOT -f "$DDIR/kron-${S}.el" -n 1 -s
done > "$FN" 2> out${S}-${T}-power.err
# Graph500 BFS
sudo "$GRAPH500DIR/omp-csr/omp-csr" -s $S >> "$FN" 2>> "out${S}-${T}-power.err"
# Baseline (do nothing, just sleep)
sudo "$GAPDIR"/sleep_baseline >> "$FN" 2>> "out${S}-${T}-power.err"
chown spollard "$FN"
chown spollard "out${S}-${T}-power.err"

# Parse
# CPU Average Power
grep -A 29 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{t+=$3;c++}END{print "GAP,BFS,Average CPU Power (W)," t/(c*PKG)}' > "$PFN"
grep -A 29 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{t+=$3;c++}END{print "Graph500,BFS,Average CPU Power (W)," t/c*PKG}' >> "$PFN"
# CPU Total Energy
grep -A 29 'RAPL on GAP BFS' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{t+=$3;c++}END{print "GAP,BFS,Total CPU Energy (J)," t/(c*PKG)}' >> "$PFN"
grep -A 29 'RAPL on Graph500 BFS' "$FN" | awk -v PKG=$PKG '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{t+=$3;c++}END{print "Graph500,BFS,Total CPU Energy (J)," t/(c*PKG)}' >> "$PFN"
# Baseline Power
grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{t+=$3;c++}END{print "NONE,Sleep,Average CPU Power (W)," t/(c*PKG)}' >> "$PFN"
grep -A 29 'baseline sleeping power' "$FN" | awk -v PKG=$PKG '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{s+=$1;t+=$3;c++}END{print "NONE,Sleep,Total CPU Energy (J)," (s*t)/(c*PKG)}' >> "$PFN"

