#!/bin/bash
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
	echo $USAGE
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

# icpc required for GraphMat
module load intel/17

# Run GraphMat PageRank
# PageRank stops when none of the vertices change
# GraphMat has been modified so alpha = 0.15
for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
	"$GRAPHMATDIR/bin/PageRank" "$DDIR/$d/$d.graphmat"
done

# Run the GraphMat SSSP
for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
	echo "SSSP root: $ROOT"
	"$GRAPHMATDIR/bin/SSSP" "$DDIR/$d/$d.graphmat" $ROOT
done

# Run the GraphMat BFS
for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
	echo "BFS root: $ROOT"
	"$GRAPHMATDIR/bin/BFS" "$DDIR/$d/$d.graphmat" $ROOT
done

# Run PowerGraph PageRank
for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/pagerank" --graph "$DDIR/$DATA.wel" --tol "$TOL" --format tsv
done

echo Starting experiment at $(date)
d="$FILE_PREFIX" # For convenience
if [ -f "$DDIR/$d/${d}.wel" ]; then
	EDGELISTFILE="$DDIR/$d/${d}.wel"
elif [ -f "$DDIR/$d/${d}.el" ]; then
	EDGELISTFILE="$DDIR/$d/${d}.el"
else
	echo "Please put an edge-list or weighted edge-list file at $DDIR/$d/$d.{wel,el}"
	exit 2
fi
# Run for GAP BFS
# It would be nice if you could read in a file for the roots
head -n $NRT "$DDIR/$d/${d}-roots.v" > "$DDIR/$d/${d}-${NRT}roots.v"
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$GAPDIR"/bfs -r $ROOT -f $EDGELISTFILE -n 1
done

# Run the GraphBIG BFS
# For this, one needs a vertex.csv file and and an edge.csv.
"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/$d" --rootfile "$DDIR/$d/${d}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS

# Run the GAP SSSP for each root
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$GAPDIR"/sssp -r $ROOT -f $EDGELISTFILE -n 1
done

# Run the GraphBIG SSSP
"$GRAPHBIGDIR/benchmark/bench_shortestPath/sssp" --dataset "$DDIR/$d" --rootfile "$DDIR/$d/${d}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS

# Run PowerGraph SSSP
# TODO: This has been updated in the code to 128
if [ "$OMP_NUM_THREADS" -gt 64 ]; then
    export GRAPHLAB_THREADS_PER_WORKER=64
	echo "WARNING: PowerGraph does not work with > 64 threads. Running on 64 threads."
else
    export GRAPHLAB_THREADS_PER_WORKER=$OMP_NUM_THREADS
fi
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/sssp" --graph "$EDGELISTFILE" --format tsv --source $ROOT
done

# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
# Run GAP PageRank
# error = sum(|newPR - oldPR|)
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$GAPDIR"/pr -f $EDGELISTFILE -i $MAXITER -t $TOL -n 1
done

# Run GraphBIG PageRank
# The original GraphBIG has --quad = sqrt(sum((newPR - oldPR)^2))
# GraphBIG error has been modified to now be sum(|newPR - oldPR|)
for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
	"$GRAPHBIGDIR/benchmark/bench_pageRank/pagerank" --dataset "$DDIR/$d" --maxiter $MAXITER --quad $TOL --threadnum $OMP_NUM_THREADS
done

echo Finished experiment at $(date)

