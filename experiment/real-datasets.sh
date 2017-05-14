#!/bin/bash
# Runs a real dataset given either a filename or a prefix of a filename.
# e.g. if you called gen-datasets.sh -f=data.out then you could specify
# either data or data.out as the first argument.
USAGE="usage: real-datasets.sh [--libdir=<dir>] [--ddir=<dir>] <filename> <num_threads>
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets"

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
if [ "$#" -lt 1 ]; then
	echo 'Please provide <filename> or the prefix of the filename'
	echo "$USAGE"
	exit 2
fi
FILE="$1"
FILE_PREFIX=$(basename ${FILE%.*})

# The reasoning behind these values are explained in run-experiment.sh
MAXITER=50 # Maximum iterations for PageRank
TOL=0.00000006
NRT=32 # Number of roots
export SKIP_VALIDATION=1
if [ "$#" -ne 2 -o "$1" = "-h" -o "$1" = "--help" ]; then
	echo "$USAGE"
	exit 2
fi
export OMP_NUM_THREADS=$2
GAPDIR="$LIBDIR/gapbs"
GRAPHBIGDIR="$LIBDIR/graphBIG"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
POWERGRAPHDIR="$LIBDIR/PowerGraph"
OUTPUT_PREFIX="$(pwd)/output/${FILE_PREFIX}/${OMP_NUM_THREADS}t"
mkdir -p "$(pwd)/output/${FILE_PREFIX}"

# icpc required for GraphMat
module load intel/17

d="$FILE_PREFIX" # For convenience
if [ -f "$DDIR/$d/${d}.wel" ]; then
	EDGELISTFILE="$DDIR/$d/${d}.wel"
elif [ -f "$DDIR/$d/${d}.el" ]; then
	EDGELISTFILE="$DDIR/$d/${d}.el"
else
	echo "Please put an edge-list or weighted edge-list file at $DDIR/$d/$d.{wel,el}"
	exit 2
fi
echo Starting experiment at $(date)

echo "Cleaning $OUTPUT_PREFIX-*"
rm -f "${OUTPUT_PREFIX}-{GAP,GraphMat,PowerGraph}-{BFS,SSSP,PR}.out"
echo "Running GAP BFS"
# It would be nice if you could read in a file for the roots
head -n $NRT "$DDIR/$d/${d}-roots.v" > "$DDIR/$d/${d}-${NRT}roots.v"
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$GAPDIR"/bfs -r $ROOT -f $EDGELISTFILE -n 1 >> "${OUTPUT_PREFIX}-GAP-BFS.out"
done

echo "Running GraphBIG BFS"
# For this, one needs a vertex.csv file and and an edge.csv.
"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/$d" --rootfile "$DDIR/$d/${d}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-BFS.out"

echo "Running GraphMat BFS"
for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
	echo "BFS root: $ROOT" >> "${OUTPUT_PREFIX}-GraphMat-BFS.out"
	"$GRAPHMATDIR/bin/BFS" "$DDIR/$d/$d.graphmat" $ROOT >> "${OUTPUT_PREFIX}-GraphMat-BFS.out"
done

echo "Running GAP SSSP"
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$GAPDIR"/sssp -r $ROOT -f $EDGELISTFILE -n 1 >> "${OUTPUT_PREFIX}-GAP-SSSP.out"
done

echo "Running GraphBIG SSSP"
"$GRAPHBIGDIR/benchmark/bench_shortestPath/sssp" --dataset "$DDIR/$d" --rootfile "$DDIR/$d/${d}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-SSSP.out"

echo "Running GraphMat SSSP"
for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
	echo "SSSP root: $ROOT" >> "${OUTPUT_PREFIX}-GraphMat-SSSP.out"
	"$GRAPHMATDIR/bin/SSSP" "$DDIR/$d/$d.graphmat" $ROOT >> "${OUTPUT_PREFIX}-GraphMat-SSSP.out"
done

echo "Running PowerGraph SSSP"
# Note that PowerGraph also sends diagnostic output to stderr so we redirect that too.
if [ "$OMP_NUM_THREADS" -gt 128 ]; then
    export GRAPHLAB_THREADS_PER_WORKER=128
	echo "WARNING: PowerGraph does not work with > 128 threads. Running on 128 threads."
else
    export GRAPHLAB_THREADS_PER_WORKER=$OMP_NUM_THREADS
fi
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/sssp" --graph "$EDGELISTFILE" --format tsv --source $ROOT >> "${OUTPUT_PREFIX}-PowerGraph-SSSP.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-SSSP.err"
done

echo "Running GAP PageRank"
# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
# error = sum(|newPR - oldPR|)
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$GAPDIR"/pr -f $EDGELISTFILE -i $MAXITER -t $TOL -n 1 >> "${OUTPUT_PREFIX}-GAP-PR.out" 
done

echo "Running GraphBIG PageRank"
# The original GraphBIG has --quad = sqrt(sum((newPR - oldPR)^2))
# GraphBIG error has been modified to now be sum(|newPR - oldPR|)
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$GRAPHBIGDIR/benchmark/bench_pageRank/pagerank" --dataset "$DDIR/$d" --maxiter $MAXITER --quad $TOL --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-PR.out" 
done

echo "Running Graphmat PageRank"
# PageRank stops when none of the vertices change
# GraphMat has been modified so alpha = 0.15
for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
	"$GRAPHMATDIR/bin/PageRank" "$DDIR/$d/$d.graphmat" >> "${OUTPUT_PREFIX}-GraphMat-PR.out"
done

echo "Running PowerGraph PageRank"
for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/pagerank" --graph "$EDGELISTFILE" --tol "$TOL" --format tsv >> "${OUTPUT_PREFIX}-PowerGraph-PR.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-PR.err"
done

echo Finished experiment at $(date)

