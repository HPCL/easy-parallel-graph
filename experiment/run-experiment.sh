#!/bin/bash
# Runs all the experiments for a given scale and thread count.
# NOTE: Must have called gen-datasets with same <scale> beforehand.
# Current algorithms:
#   Breadth First Search, Single Source Shortest Paths, PageRank
# Current platforms:
#   GraphBIG, Graph500, GAP, GraphMat, PowerGraph (SSSP & PR only)
# Recommended usage for bash
#   ./run-experiment.sh $S $T > out${S}-${T}.log 2> out${S}-${T}.err &
#   disown %<jobnum> # This can be found out using jobs
USAGE="usage: run-experiment.sh [--libdir=<dir>] [--ddir=<dir>] <scale> <num-threads>
	scale: 2^scale = number of vertices
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets" # 2^{<scale>} = Number of vertices.

# The edge factor (number of edges per vertex) is the default of 16.
DDIR="$(pwd)/datasets" # Dataset directory
LIBDIR="$(pwd)/lib"
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
# Set variables based on the command line arguments
S=$1
export OMP_NUM_THREADS=$2
GAPDIR="$LIBDIR/gapbs"
GRAPHBIGDIR="$LIBDIR/graphBIG"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
POWERGRAPHDIR="$LIBDIR/PowerGraph"
OUTPUT_PREFIX="$(pwd)/output/kron-$S/${OMP_NUM_THREADS}t"
mkdir -p "$(pwd)/output/kron-$S"

# Set some other variables used throughout the experiment
# PageRank is usually represented as a 32-bit float,
# so ~6e-8*nvertices is the minimum absolute error detectable
# We set alpha = 0.15 in the respective source codes.
# NOTE: GraphMat doesn't seem to compute iterations in the same way.
MAXITER=50 # Maximum iterations for PageRank
TOL=0.00000006
NRT=32 # Number of roots
export SKIP_VALIDATION=1

# Load all the modules here
module load intel/17

echo Starting experiment at $(date)

echo -n "Running Graph500 BFS"
# This isn't working, so just regenerate the data
#omp-csr/omp-csr -s $S -o "$DDIR/kron-$S/kron-${S}.graph500" -r "$DDIR/kron-$S/kron-${S}.roots"
if [ "$OMP_NUM_THREADS" -gt 1 ]; then
	echo " with OpenMP"
	"$GRAPH500DIR/omp-csr/omp-csr" -s $S >> "${OUTPUT_PREFIX}-Graph500-BFS.out"
else
	echo " sequentially"
	"$GRAPH500DIR/seq-csr/seq-csr" -s $S >> "${OUTPUT_PREFIX}-Graph500-BFS.out"
fi

echo "Running GAP BFS"
# It would be nice if you could read in a file for the roots
# Just do one trial to be the same as the rest of the experiments
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.v"); do
	"$GAPDIR"/bfs -r $ROOT -f "$DDIR/kron-$S/kron-${S}.el" -n 1 -s >> "${OUTPUT_PREFIX}-GAP-BFS.out"
done

echo "Running GAP SSSP"
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.v"); do
	"$GAPDIR"/sssp -r $ROOT -f "$DDIR/kron-$S/kron-${S}.el" -n 1 -s >> "${OUTPUT_PREFIX}-GAP-SSSP.out"
done

echo "Running GAP PageRank"
# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
# error = sum(|newPR - oldPR|)
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.v"); do
	"$GAPDIR"/pr -f "$DDIR/kron-$S/kron-${S}.el" -i $MAXITER -t $TOL -n 1 >> "${OUTPUT_PREFIX}-GAP-PR.out"
done

echo "Running PowerGraph SSSP"
# Note that PowerGraph also sends diagnostic output to stderr so we redirect that too.
if [ "$OMP_NUM_THREADS" -gt 128 ]; then
    export GRAPHLAB_THREADS_PER_WORKER=128
	echo "WARNING: PowerGraph does not work with > 128 threads. Running on 128 threads."
else
    export GRAPHLAB_THREADS_PER_WORKER=$OMP_NUM_THREADS
fi
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/sssp" --graph "$DDIR/kron-$S/kron-${S}.el" --format tsv --source $ROOT >> "${OUTPUT_PREFIX}-PowerGraph-SSSP.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-SSSP.err"
done

echo "Running PowerGraph PageRank"
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/pagerank" --graph "$DDIR/kron-$S/kron-${S}.el" --tol "$TOL" --format tsv >> "${OUTPUT_PREFIX}-PowerGraph-PR.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-PR.err"
done

echo "Running GraphMat BFS"
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.1v"); do
	echo "BFS root: $ROOT" >> "${OUTPUT_PREFIX}-GraphMat-BFS.out"
	"$GRAPHMATDIR/bin/BFS" "$DDIR/kron-$S/kron-${S}.graphmat" $ROOT >> "${OUTPUT_PREFIX}-GraphMat-BFS.out"
done

echo "Running GraphMat SSSP"
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.1v"); do
	echo "SSSP root: $ROOT" >> "${OUTPUT_PREFIX}-GraphMat-SSSP.out"
	"$GRAPHMATDIR/bin/SSSP" "$DDIR/kron-$S/kron-${S}.graphmat" $ROOT >> "${OUTPUT_PREFIX}-GraphMat-SSSP.out"
done

echo "Running GraphMat PageRank"
# PageRank stops when none of the vertices change
# GraphMat has been modified so alpha = 0.15
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.1v"); do
	"$GRAPHMATDIR/bin/PageRank" "$DDIR/kron-$S/kron-${S}.graphmat" >> "${OUTPUT_PREFIX}-GraphMat-PR.out"
done

echo "Running GraphBIG BFS"
# For this, one needs a vertex.csv file and and an edge.csv.
head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.v" > "$DDIR/kron-$S/kron-${S}-${NRT}roots.v"
"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/kron-$S" --rootfile "$DDIR/kron-$S/kron-${S}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-BFS.out"

echo "Running GraphBIG SSSP"
"$GRAPHBIGDIR/benchmark/bench_shortestPath/sssp" --dataset "$DDIR/kron-$S" --rootfile "$DDIR/kron-$S/kron-${S}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-SSSP.out"

echo "Running GraphBIG PageRank"
# The original GraphBIG has --quad = sqrt(sum((newPR - oldPR)^2))
# GraphBIG error has been modified to now be sum(|newPR - oldPR|)
for ROOT in $(head -n $NRT "$DDIR/kron-$S/kron-${S}-roots.v"); do
	"$GRAPHBIGDIR/benchmark/bench_pageRank/pagerank" --dataset "$DDIR/kron-$S" --maxiter $MAXITER --quad $TOL --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-PR.out"
done

echo Finished experiment at $(date)

