#!/bin/bash
# Given an algorithm and dataset, recommend the best performing
# graph processing library
USAGE='usage: recommend.sh [--libdir=<dir>] [--ddir=<dir>] <algorithm> <dataset>
	<algorithm> can be one of: PageRank, SSSP, BFS
	<dataset> can be either kron-<n> or a file prefix (e.g.
		cit-Patents without .txt) as generated from gen-datasets.sh
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets'
# Process options
DDIR="$(pwd)/datasets" # Dataset directory
LIBDIR="$(pwd)/lib"
OUTDIR="$(pwd)/output"
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
	--outdir=*)
		OUTDIR=${arg#*=}
		if [ ${OUTDIR:0:1} != '/' ]; then # Relative
			OUTDIR="$(pwd)/$OUTDIR"
		fi
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

# Process arguments
if [ "$#" -lt 2 ]; then
	echo 'Please provide <algorithm> and <dataset>'
	echo "$USAGE"
	exit 2
fi
ALGORITHMS="PageRank SSSP BFS"
# Set variables based on the command line arguments
ALGO="$1"
echo "$ALGORITHMS" | grep -q -i "$ALGO"
if [ "$?" -ne 0 ]; then
	echo "<algorithm> must be one of: $ALGORITHMS"
	exit 2
fi
DSET="$2"
if [ ! -d "$DDIR/$DSET" ]; then
	echo "Please select a dataset from the directories in $DDIR"
	exit 2
fi
if [ "$OSNAME" = Darwin ]; then
	NUM_THREADS=$(sysctl -n hw.ncpu) # The number of virtual cores (hyperthreading is counted)
else
	NUM_THREADS=$(grep -c ^processor /proc/cpuinfo)
fi

case $DSET in 
kron-*)
	S=${DSET#kron-}
	./run-experiment.sh $S $NUM_THREADS
	./parse-output.sh $S
	;;
*)
	./real-datasets.sh $DSET $NUM_THREADS
	./parse-output.sh -f=$DSET
	;;
esac

PARSED_FILE="$OUTDIR/parsed-$DSET-$NUM_THREADS.csv"

# Simple parsing to get the average time for one algorithm and one time
LIBRARIES="GAP GraphBIG PowerGraph GraphMat"
for LIB in $LIBRARIES; do
	THE_TIMES=$(grep -E "$LIB,$ALGO,Time,*" "$PARSED_FILE" | cut -d ',' -f 4)
	AVG_TIME=$(echo "$THE_TIMES" | awk '{avg+=$1} END {print avg / NR}')
	printf "%s: %f sec\n" "$LIB" "$AVG_TIME"
done

