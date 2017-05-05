#!/bin/bash
# Parse the output from run-experiment.sh or real-datasets.sh
# and save to <outdir>/parsed-<fn>.csv
# If <fn> is provided then this script searches for the directory <fn>
# without the filename extension, e.g. -f=datasets/data.out causes this to
# search <outdir>/data and 20 causes this to search in <outdir>/kron-20." 
USAGE="usage: parse-output.sh [--outdir=<dir>] -f=<fn>|<scale>
	<fn> is a filename or prefix which real-datasets.sh has been run.
	<scale> may be an integer between 1 and 99 inclusive.
	--outdir: directory where the data is stored. default: ./output"

OUTDIR="$(pwd)/output"
for arg in "$@"; do
	case $arg in
	--outdir=*)
		OUTDIR=${arg#*=}
		if [ ${OUTDIR:0:1} != '/' ]; then # Relative
			OUTDIR="$(pwd)/$OUTDIR"
		fi
		shift
	;;
	-f=*)
		FILE=${arg#*=}
		FILE_PREFIX=$(basename ${FILE%.*})
		shift
	;;
	-h|--help|-help)
		echo "$USAGE"
		exit 0
	;;
	*)	# Default
		# Do nothing
	esac
done
if [ -z "$FILE" ]; then
	if [ "$#" -lt 1 -o "$#" -gt 1 ]; then
		echo 'Please provide <scale> or -f=<filename>'
		echo "$USAGE"
		exit 2
	fi
	case $1 in
	[1-9]|[1-9][0-9]*) # scale between 1--99 is robust enough
		S=$1
		FILE_PREFIX="kron-$S"
	;;
	*) # Default
		echo "<scale> must be between 1--99"
		exit 2
	;;
	esac
fi

OUTFN="$OUTDIR/parsed-$FILE_PREFIX.csv"
LOG_DIR="$OUTDIR/$FILE_PREFIX"
# Assumes the experiment is run $NRT times ($NRT roots or $NRT PageRanks)
NRT=32
# Header: Sys,Algo,Metric,Time

echo -n "Parsing GraphBIG for"
echo "Removing old parsed files and starting fresh..."
rm -f "$OUTDIR"/parsed-$FILE_PREFIX-*.csv

for FN in $(find "$LOG_DIR" -maxdepth 1 -name '*t-GraphBIG-*.out'); do
	f=$(basename $FN)
	T=${f%%t[^0-9]*}
	OUTFN="$OUTDIR/parsed-$FILE_PREFIX-$T.csv"
	ALGO=$(expr match "${f%.out}" '.*\(-.*\)')
	ALGO=${ALGO#-}
	echo -n "; $ALGO $T threads"
	if [ "$ALGO" = BFS ]; then
		echo -n "GraphBIG,BFS,File reading," >> "$OUTFN"
		grep -A 7 "Benchmark: BFS" "$FN" | awk -v T=0 '/time/{if(T%2==0){print $3} T++}' | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		grep -A $((4 * $NRT + 4)) "Benchmark: BFS" "$FN" | tail -n+5 | awk '/time/{print "GraphBIG,BFS,Time," $3}' >> "$OUTFN"
	elif [ "$ALGO" = SSSP ]; then
		echo -n 'GraphBIG,SSSP,File reading,' >> "$OUTFN"
		grep -A 7 'Benchmark: sssp' "$FN" | awk -v T=0 '/time/{if(T%2==0){print $3} T++}' | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		grep -A $((2 * $NRT + 4)) 'Benchmark: sssp' "$FN" | tail -n+5 | awk '/time/{print "GraphBIG,SSSP,Time," $3}' >> "$OUTFN"
	elif [ "$ALGO" = PR ]; then
		echo -n 'GraphBIG,PageRank,File reading,' >> "$OUTFN"
		grep -A 7 "Degree Centrality" "$FN" | awk -v T=0 '/time/{if(T%2==0){print $3} T++}' | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		grep 'iteration #' "$FN" | awk '{print "GraphBIG,PageRank,Iterations," $4}' >> "$OUTFN"
		grep -A 11 "Degree Centrality" "$FN" | awk -v T=1 '/time/{if(T%2==0){print "GraphBIG,PageRank,Time," $3} T++}' >> "$OUTFN"
	fi
done
echo #\n

echo -n "Parsing Graph500 for BFS, threadcounts"
for FN in $(find "$LOG_DIR" -maxdepth 1 -name '*t-Graph500-BFS.out'); do
	f=$(basename $FN)
	T=${f%%t[^0-9]*}
	OUTFN="$OUTDIR/parsed-$FILE_PREFIX-$T.csv"
	echo -n " $T"

	echo -n "Graph500,BFS,graph generation," >> "$OUTFN"
	echo $(grep "generation_time" "$FN" | awk '{print $2}') >> "$OUTFN"
	echo -n 'Graph500,BFS,Data structure build,' >> "$OUTFN"
	echo $(grep "construction_time" "$FN" | awk '{print $2}') >> "$OUTFN"
	awk '/bfs_time\[/{print "Graph500,BFS,Time," $2}' "$FN" >> "$OUTFN"
done
echo #\n

echo -n "Parsing GraphMat for"
for FN in $(find "$LOG_DIR" -maxdepth 1 -name '*t-GraphMat-*.out'); do
	f=$(basename $FN)
	T=${f%%t[^0-9]*}
	OUTFN="$OUTDIR/parsed-$FILE_PREFIX-$T.csv"
	ALGO=$(expr match "${f%.out}" '.*\(-.*\)')
	ALGO=${ALGO#-}
	echo -n "; $ALGO $T threads"
	if [ "$ALGO" = BFS ]; then
		echo -n "GraphMat,BFS,File reading," >> "$OUTFN"
		grep -A 4 'BFS root:' "$FN" | awk -F ':' '/, time/{print $2}' | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		# The time to build, sort, allocate the data structure
		# XXX: This surprisingly takes between 0.7-2.9 seconds. Why the discrepancy?
		grep -A 17 'BFS root:' "$FN" | awk '/A from memory/{print "GraphMat,BFS,Data structure build," $(NF-1)}' >> "$OUTFN"
		# The time to build, sort, allocate the data structure.
		grep -A 20 'BFS root:' "$FN" | awk '/Time/{print "GraphMat,BFS,Time," ($3/1000)}' >> "$OUTFN"
	elif [ "$ALGO" = SSSP ]; then
		echo -n 'GraphMat,SSSP,File reading,' >> "$OUTFN"
		grep -A 4 'SSSP root:' "$FN" | awk -F ':' '/, time/{print $2}' | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		grep -A 17 'SSSP root:' "$FN" | awk '/A from memory/{print "GraphMat,SSSP,Data structure build," $(NF-1)}' >> "$OUTFN"
		grep -A 20 'SSSP root:' "$FN" | awk '/Time/{print "GraphMat,SSSP,Time," ($3/1000)}' >> "$OUTFN"
	elif [ "$ALGO" = PR ]; then
		# NOTE: GraphMat PageRank goes for 149 iterations
		echo -n 'GraphMat,PageRank,File reading,' >> "$OUTFN"
		grep -B 18 "PR Time" "$FN" | awk -F ':' '/, time/{print $2}' | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		grep -B 5 "PR Time" "$FN" | awk '/A from memory/{print "GraphMat,PageRank,Data structure build," $(NF-1)}' >> "$OUTFN"
		grep -B 1 "PR Time" "$FN" | awk '/Completed/{print "GraphMat,PageRank,Iterations," $2}' >> "$OUTFN"
		awk '/PR Time/{print "GraphMat,PageRank,Time," ($4/1000)}' "$FN" >> "$OUTFN"
	fi
done
echo #\n

echo -n "Parsing GAP for"
for FN in $(find "$LOG_DIR" -maxdepth 1 -name '*t-GAP-*.out'); do
	f=$(basename $FN)
	T=${f%%t[^0-9]*}
	OUTFN="$OUTDIR/parsed-$FILE_PREFIX-$T.csv"
	ALGO=$(expr match "${f%.out}" '.*\(-.*\)')
	ALGO=${ALGO#-}
	echo -n "; $ALGO $T threads"
	if [ "$ALGO" = BFS ]; then
		echo -n "GAP,BFS,File reading," >> "$OUTFN"
		awk -v NRT=$NRT '/Read Time:/{i++; if(i<=NRT)print $3}' "$FN" | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		awk -v NRT=$NRT '/Build Time:/{i++; if(i<=NRT)print "GAP,BFS,Data structure build," $3}' "$FN" >> "$OUTFN"
		awk -v NRT=$NRT '/Average Time:/{i++; if(i<=NRT)print "GAP,BFS,Time," $3}' "$FN" >> "$OUTFN"
	elif [ "$ALGO" = SSSP ]; then
		echo -n 'GAP,SSSP,File reading,' >> "$OUTFN"
		awk -v NRT=$NRT '/Read Time:/{i++; if(i<=NRT)print $3}' "$FN" | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		awk -v NRT=$NRT '/Build Time:/{i++; if(i<=NRT)print "GAP,SSSP,Data structure build," $3}' "$FN" >> "$OUTFN"
		awk -v NRT=$NRT '/Average Time:/{i++; if(i<=NRT)print "GAP,SSSP,Time," $3}' "$FN" >> "$OUTFN"
	elif [ "$ALGO" = PR ]; then
		echo -n 'GAP,PageRank,File reading,' >> "$OUTFN"
		awk -v NRT=$NRT '/Read Time:/{i++; if(i<=NRT)print $3}' "$FN" | awk '{s+=$1}END{print s/NR}' >> "$OUTFN"
		awk -v NRT=$NRT '/Build Time:/{i++; if(i<=NRT)print "GAP,PageRank,Data structure build," $3}' "$FN" >> "$OUTFN"
		grep -B 2 'Average Time:' "$FN" | awk '/^\s*[0-9]+/{print "GAP,PageRank,Iterations," $1}' >> "$OUTFN"
		awk -v NRT=$NRT '/Average Time:/{i++; if(i<=NRT)print "GAP,PageRank,Time," $3}' "$FN" >> "$OUTFN"
	fi
done
echo #\n

echo -n "Parsing PowerGraph for"
for FN in $(find "$LOG_DIR" -maxdepth 1 -name '*t-PowerGraph-*.out'); do
	f=$(basename $FN)
	T=${f%%t[^0-9]*}
	OUTFN="$OUTDIR/parsed-$FILE_PREFIX-$T.csv"
	ERRFN="${FN%.out}.err"
	ALGO=$(expr match "${f%.out}" '.*\(-.*\)')
	ALGO=${ALGO#-}
	echo -n "; $ALGO $T threads"
	if [ "$ALGO" = SSSP ]; then
		awk -v NRT=$NRT '/Finished Running engine/{i++; if(i<=NRT)print "PowerGraph,SSSP,Time," $5}' "$FN" >> "$OUTFN"
		awk -v NRT=$NRT '/iterations completed/{i++; if(i<=NRT)print "PowerGraph,SSSP,Iterations," $(NF-2)}' "$ERRFN" >> "$OUTFN"
	elif [ "$ALGO" = PR ]; then
		awk -v NRT=$NRT '/Finished Running engine/{i++; if(i<=NRT)print "PowerGraph,PageRank,Time," $5}' "$FN" >> "$OUTFN"
		awk -v NRT=$NRT '/iterations completed/{i++; if(i<=NRT)print "PowerGraph,PageRank,Iterations," $(NF-2)}' "$ERRFN" >> "$OUTFN"
	fi
done
echo #\n

