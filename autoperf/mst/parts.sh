#!/bin/bash
# usage: sudo -E ./parts.sh
# Assumes you've already done . run build
LIB_DIR="$(pwd)/lib"
module load tau # Also loads the PAPI environment variable
export POWER_PROFILING=1
export TAU_MAKEFILE="$TAU_DIR/x86_64/lib/Makefile.tau-papi-pdt-openmp" # I don't think this is needed when sampling
export DDIR=/home/users/spollard/graphalytics/all-datasets/PBBSInput
PBBS_DIR="$LIB_DIR/pbbs-msf/minSpanningForest"
XPS_DIR="$LIB_DIR/xpscode/MSTSC"
GALOIS_DIR="$LIB_DIR/Galois-2.2.1"
ROOTDIR="$(pwd)/output"
OMP_NUM_THREADS=72
export OMP_NUM_THREADS
PFN="$ROOTDIR/parsed-power-$OMP_NUM_THREADS.txt"
PKG=2
EPV=8
RT_TYPES="ER B G"
CVERTS=2000 # Changed vertices
INS_PCT=50 # Percent insertions
NS='sudo -u spollard'

# arguments: S, RT, INS_PCT
run_experiment()
{
    S=$1
    RT=$2
    INS_PCT=$3
    # Generate Dataset
    cd "$XPS_DIR"
    N_VERT=$(echo 2 ^ $S | bc)
    echo "Creating RMAT at scale $S, $EPV, $RT" # LOG
    if [ "$RT" = G ]; then
        $NS "$XPS_DIR/../RMAT/driverForRmat" $S 6 $EPV 0.45 0.15 0.15 0.25 "$DDIR/rmat${S}${EPV}_G-orig.wel"
    elif [ "$RT" = ER ]; then
        $NS "$XPS_DIR/../RMAT/driverForRmat" $S 6 $EPV 0.25 0.25 0.25 0.25 "$DDIR/rmat${S}${EPV}_ER-orig.wel"
    elif [ "$RT" = B ]; then
        $NS "$XPS_DIR/../RMAT/driverForRmat" $S 6 $EPV 0.55 0.15 0.15 0.15 "$DDIR/rmat${S}${EPV}_B-orig.wel"
    fi
    mv "$DDIR/rmat${S}${EPV}_${RT}-orig.wel" tmp
    $NS awk '{printf "%d %d %d\n", $1, $2, int(rand()*100)}' tmp > "$DDIR/rmat${S}${EPV}_${RT}-orig.wel"
    rm tmp
    $NS "$XPS_DIR/tEx.out" "$DDIR/rmat${S}${EPV}_${RT}-orig.wel" $(awk '{print $1; exit}' "$DDIR/rmat${S}${EPV}_${RT}-orig.wel")
    $NS "$XPS_DIR/bfs.out" "$XPS_DIR/GraphCx.txt" $(awk '{print $1; exit}' "$XPS_DIR/GraphCx.txt")
    rm "$XPS_DIR/Graphallx.txt" # May not be connected
    mv "$XPS_DIR/Graphall.txt" "$DDIR/rmat${S}${EPV}_${RT}.wel"
    rm "$XPS_DIR/GraphCx.txt" # Duplicate
    mv "$XPS_DIR/GraphC.txt" "$DDIR/rmat${S}${EPV}_${RT}.cert"
    rm "$XPS_DIR/Graphdiff.txt" # Empty
    mv "$XPS_DIR/Graphdiffx.txt" "$DDIR/rmat${S}${EPV}_${RT}.diff"
    "$NS $XPS_DIR/cE.out" "$DDIR/rmat${S}${EPV}_${RT}.wel" ${CVERTS} 100 $INS_PCT > "$DDIR/changedrmat${S}${EPV}_${RT}_${CVERTS}"
    sort -n -k1 -k2 "$DDIR/changedrmat${S}${EPV}_${RT}_${CVERTS}" > "$DDIR/changedrmat${S}${EPV}_${RT}_${CVERTS}S"
    $NS "$GALOIS_DIR/build/release/tools/graph-convert/graph-convert" -intedgelist2gr "$DDIR/rmat${S}${EPV}_${RT}.wel" "$DDIR/rmat${S}${EPV}_${RT}.gr"

    # Run experiment
    sudo "$GALOIS_DIR/build/power/apps/boruvka/boruvka" -t=$OMP_NUM_THREADS "$DDIR/rmat${S}${EPV}_${RT}.gr" | tee "$ROOTDIR/galois-${S}${EPV}_$RT.log"
    # ./a.out <diff_file> <certificate> <set of changed edges> <upper bound of edge weight> <number of vertices>  <number of threads>
    sudo "$XPS_DIR/a.out" "$DDIR/rmat${S}${EPV}_${RT}.diff" "$DDIR/rmat${S}${EPV}_${RT}.cert" "$DDIR/changedrmat${S}${EPV}_${RT}_${CVERTS}S" 100 $N_VERT $OMP_NUM_THREADS | tee "$ROOTDIR/mst-${S}${EPV}_$RT.log"
    chown spollard "$ROOTDIR/mst-${S}${EPV}_$RT.log"
    chown spollard "$ROOTDIR/galois-${S}${EPV}_$RT.log"
    
    # Parse
    cd "$ROOTDIR"
    grep -A 30 'Starting create_tree' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "MST,create_tree,%s_%s_%s,Total CPU Energy (J),%f\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' >> "$PFN"
    grep -A 30 'Starting create_tree' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "MST,create_tree,%s_%s_%s,Average CPU Power (W),%f\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' >> "$PFN"
    grep -A 30 'Starting create_tree' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/^[0-9]+\.[0-9]+ s/{printf "MST,create_tree,%s_%s_%s,Time (s),%s\n",S,EPV,RMT,$1;exit}' >> "$PFN"

    grep -A 30 'Starting first_pass' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "MST,first_pass,%s_%s_%s,Total CPU Energy (J),%f\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' >> "$PFN"
    grep -A 30 'Starting first_pass' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "MST,first_pass,%s_%s_%s,Average CPU Power (W),%f\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' >> "$PFN"
    grep -A 30 'Starting first_pass' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/^[0-9]+\.[0-9]+ s/{printf "MST,first_pass,%s_%s_%s,Time (s),%s\n",S,EPV,RMT,$1;exit}' >> "$PFN"

    grep -A 30 'Starting process_insertions' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "MST,process_insertions,%s_%s_%s,Total CPU Energy (J),%f\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' >> "$PFN"
    grep -A 30 'Starting process_insertions' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "MST,process_insertions,%s_%s_%s,Average CPU Power (W),%f\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' >> "$PFN"
    grep -A 30 'Starting process_insertions' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/^[0-9]+\.[0-9]+ s/{printf "MST,process_insertions,%s_%s_%s,Time (s),%s\n",S,EPV,RMT,$1;exit}' >> "$PFN"

    grep -B 31 'Time for Deletion' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "MST,process_deletions,%s_%s_%s,Total CPU Energy (J),%f\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' >> "$PFN"
    grep -B 31 'Time for Deletion' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "MST,process_deletions,%s_%s_%s,Average CPU Power (W),%f\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' >> "$PFN"
    grep -B 31 'Time for Deletion' mst-${S}${EPV}_$RT.log | awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/^[0-9]+\.[0-9]+ s/{printf "MST,process_deletions,%s_%s_%s,Time (s),%s\n",S,EPV,RMT,$1;exit}' >> "$PFN"

    awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "Galois,All,%s_%s_%s,Total CPU Energy (J),%s\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' galois-${S}${EPV}_$RT.log >> "$PFN"
    awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \*/{c++;if(c%PKG==0){printf "Galois,All,%s_%s_%s,Average CPU Power (W),%s\n",S,EPV,RMT,t+$3;t=0}else{t+=$3}}' galois-${S}${EPV}_$RT.log >> "$PFN"
    awk -v PKG=$PKG -v S=$S -v EPV=$EPV -v RMT=$RT '/^[0-9]+\.[0-9]+ s/{printf "Galois,All,%s_%s_%s,Time (s),%s\n",S,EPV,RMT,$1;exit}' galois-${S}${EPV}_$RT.log >> "$PFN"

}

run_experiment 22 ER 10
run_experiment 22 G 10
run_experiment 22 B 10

run_experiment 22 ER 25
run_experiment 22 G 25
run_experiment 22 B 25

run_experiment 22 ER 50
run_experiment 22 G 50
run_experiment 22 B 50

run_experiment 22 ER 75
run_experiment 22 G 75
run_experiment 22 B 75

run_experiment 22 ER 75
run_experiment 22 G 75
run_experiment 22 B 75

run_experiment 22 ER 90
run_experiment 22 G 90
run_experiment 22 B 90

run_experiment 22 ER 100
run_experiment 22 G 100
run_experiment 22 B 100

run_experiment 23 ER 10
run_experiment 23 G 10
run_experiment 23 B 10

run_experiment 23 ER 25
run_experiment 23 G 25
run_experiment 23 B 25

run_experiment 23 ER 50
run_experiment 23 G 50
run_experiment 23 B 50

run_experiment 23 ER 75
run_experiment 23 G 75
run_experiment 23 B 75

run_experiment 23 ER 75
run_experiment 23 G 75
run_experiment 23 B 75

run_experiment 23 ER 90
run_experiment 23 G 90
run_experiment 23 B 90

run_experiment 23 ER 100
run_experiment 23 G 100
run_experiment 23 B 100

run_experiment 24 ER 10
run_experiment 24 G 10
run_experiment 24 B 10

run_experiment 24 ER 25
run_experiment 24 G 25
run_experiment 24 B 25

run_experiment 24 ER 50
run_experiment 24 G 50
run_experiment 24 B 50

run_experiment 24 ER 75
run_experiment 24 G 75
run_experiment 24 B 75

run_experiment 24 ER 75
run_experiment 24 G 75
run_experiment 24 B 75

run_experiment 24 ER 90
run_experiment 24 G 90
run_experiment 24 B 90

run_experiment 24 ER 100
run_experiment 24 G 100
run_experiment 24 B 100

run_experiment 25 ER 10
run_experiment 25 G 10
run_experiment 25 B 10

run_experiment 25 ER 25
run_experiment 25 G 25
run_experiment 25 B 25

run_experiment 25 ER 50
run_experiment 25 G 50
run_experiment 25 B 50

run_experiment 25 ER 75
run_experiment 25 G 75
run_experiment 25 B 75

run_experiment 25 ER 75
run_experiment 25 G 75
run_experiment 25 B 75

run_experiment 25 ER 90
run_experiment 25 G 90
run_experiment 25 B 90

run_experiment 25 ER 100
run_experiment 25 G 100
run_experiment 25 B 100
