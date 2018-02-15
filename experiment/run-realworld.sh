#!/bin/bash
set -o history -o histexpand
# Runs a real dataset given either a filename or a prefix of a filename.
# e.g. if you called gen-datasets.sh -f=data.out then you could specify
# either data or data.out as the first argument.
USAGE="usage: real-realworld.sh [--libdir=<dir>] [--ddir=<dir>] <filename> <num_threads>
	<filename> can be the whole file or the prefix. e.g. datasets/cit-Patents
		or datasets/cit-Patents/cit-Patents.el
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets
	--copy-to=<tmpdir>: copy to temporary storage, delete after experiment.
		Default: Don't copy.
	NOTE: Things I haven't added as command line options but you change:
	RUN_* (run each of the experiments). Set this to 0 if you don't want
		to run that package"

DDIR="$(pwd)/datasets" # Dataset directory
LIBDIR="$(pwd)/lib"
NRT=32 # Number of roots
RUN_GAP=1
RUN_GALOIS=1
RUN_GRAPHMAT=1
RUN_GRAPHBIG=1
RUN_POWERGRAPH=1

unset COPY # can copy to a faster, temporary filesystem
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
	--num-roots=*)
		NRT=${arg#*=}
		case $NRT in
		''|0|*[!0-9]*)
			echo "num-roots must be a positive integer"
			exit 2
			;;
		*)
			if [ "$NRT" -gt 32 ]; then
				# XXX: This is a hacky way to deal with this issue
				echo 'Error: num-roots must be <=32. If you really want it to be more'
				echo 'than this, change NRT to 2*(roots you want) in gen-datasets.sh'
				exit 2
			fi
			;;
		esac
		shift
	;;
	--copy-to=*)
		COPY=${arg#*=}
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
# Handle KONECT style where the file looks like out.actor-collaboration
if [ "$FILE_PREFIX" = 'out' ]; then
	FILE_PREFIX=$(basename $FILE)
	FILE_PREFIX=${FILE_PREFIX#out.}
fi

# The reasoning behind these values are explained in run-synthetic.sh
MAXITER=50 # Maximum iterations for PageRank
TOL=0.00000006
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
GALOISDIR="$LIBDIR/Galois-2.2.1/build/default"
OUTPUT_PREFIX="$(pwd)/output/${FILE_PREFIX}/${OMP_NUM_THREADS}t"
mkdir -p "$(pwd)/output/${FILE_PREFIX}"

# input: Exit code of the previously-run command and the executable to search for
# output: prints the command if the exit code is nonzero
set -o history
check_status ()
{
	# Because of the stupid way Bash handles history, we need to preprocess
	# this. You should provide the exit code as $1 and the binary as $2.
	# for example, check_status $? bin/bfs. More of the path is better, since
	# oftentimes you use string elsewhere in the same giant if block.
	if [ "$1" -ne 0 ]; then
		LASTCMD=$(history 1)
		echo Entire bash statement was: $LASTCMD
		LASTCMD=$(echo $LASTCMD | grep -o -P "; .*?$2.*?;")
		LASTCMD=${LASTCMD##;*do }
		LASTCMD=${LASTCMD##;*then }
		LASTCMD=${LASTCMD##;*else }
		LASTCMD=${LASTCMD%%>*}
		echo "There was a problem with $(eval echo $LASTCMD)"
		exit 1
	fi 
}

d="$FILE_PREFIX" # For convenience
if [ "$(head -n 1 $DDIR/$d/edge.csv)" = "SRC,DEST" ]; then
	echo "Using unweighted graph where possible"
	EDGELISTFILE="$DDIR/$d/${d}.el"
	GAP_EDGELISTFILE="$DDIR/$d/${d}.sg"
	GALOIS_EDGELISTFILE="$DDIR/$d/${d}.gr" # vgr (unweighted) doesn't work for Galois
elif [ "$(head -n 1 $DDIR/$d/edge.csv)" = "SRC,DEST,WEIGHT" ]; then
	echo "Using weighted graph where possible"
	EDGELISTFILE="$DDIR/$d/${d}.wel"
	GAP_EDGELISTFILE="$DDIR/$d/${d}.wsg"
	GALOIS_EDGELISTFILE="$DDIR/$d/${d}.gr"
else
	echo "Please put an edge-list or weighted edge-list file at $DDIR/$d/$d.{wel,el}"
	exit 2
fi
if [ -n "$COPY" ]; then
	mkdir -p "$COPY/$d"
	cp $DDIR/$d/* "$COPY/$d"
	DDIR="$COPY"
	echo "Copied data to $DDIR"
fi
echo Starting experiment at $(date)

echo Note: Files of the form
echo "${OUTPUT_PREFIX}-{GAP,GraphMat,PowerGraph,Galois}-{BFS,SSSP,PR,TC}.out"
echo get overwritten.

# It would be nice if you could read in a file for the roots
if [ "$RUN_GAP" = 1 ]; then 
	echo "Running GAP BFS"
	rm -f "${OUTPUT_PREFIX}-GAP-"{BFS,SSSP,PR,TC}.out
	head -n $NRT "$DDIR/$d/${d}-roots.v" > "$DDIR/$d/${d}-${NRT}roots.v"
	for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
		"$GAPDIR"/bfs -r $ROOT -f $GAP_EDGELISTFILE -n 1 >> "${OUTPUT_PREFIX}-GAP-BFS.out"
		check_status $?
	done

	echo "Running GAP SSSP"
	for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
		"$GAPDIR"/sssp -r $ROOT -f "$DDIR/$d/${d}.el" -n 1 >> "${OUTPUT_PREFIX}-GAP-SSSP.out"
		check_status $?
	done

	echo "Running GAP PageRank"
	# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
	# error = sum(|newPR - oldPR|)
	for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
		"$GAPDIR"/pr -f $GAP_EDGELISTFILE -i $MAXITER -t $TOL -n 1 >> "${OUTPUT_PREFIX}-GAP-PR.out" 
		check_status $?
	done

	echo "Running GAP TriangleCount"
	"$GAPDIR"/tc -f "$GAP_EDGELISTFILE" -n $NRT >> "${OUTPUT_PREFIX}-GAP-TriangleCount.out"
	check_status $?
fi


if [ "$RUN_GRAPHBIG" = 1 ]; then 
	echo "Running GraphBIG BFS"
	rm -f "${OUTPUT_PREFIX}-GraphBIG-"{BFS,SSSP,PR,TC}.out
	# For this, one needs a vertex.csv file and and an edge.csv.
	"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/$d" --rootfile "$DDIR/$d/${d}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-BFS.out"
	check_status $?

	echo "Running GraphBIG SSSP"
	"$GRAPHBIGDIR/benchmark/bench_shortestPath/sssp" --dataset "$DDIR/$d" --rootfile "$DDIR/$d/${d}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-SSSP.out"
	check_status $?

	echo "Running GraphBIG PageRank"
	# The original GraphBIG has --quad = sqrt(sum((newPR - oldPR)^2))
	# GraphBIG error has been modified to now be sum(|newPR - oldPR|)
	for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
		"$GRAPHBIGDIR/benchmark/bench_pageRank/pagerank" --dataset "$DDIR/$d" --maxiter $MAXITER --quad $TOL --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-PR.out" 
		check_status $?
	done

	# TODO: Fix this---currently counts 0 triangles for facebook_combined
	echo "Running GraphBIG TriangleCount"
	for dummy in $(head -n $NRT "$DDIR/$d/$d-roots.1v"); do
		"$GRAPHBIGDIR/benchmark/bench_triangleCount/tc" --dataset "$DDIR/$d" --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-TriangleCount.out"
		check_status $?
	done
fi

if [ "$RUN_GRAPHMAT" = 1 ]; then 
	echo "Running GraphMat BFS"
	rm -f "${OUTPUT_PREFIX}-GraphMat-"{BFS,SSSP,PR,TC}.out
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		echo "BFS root: $ROOT" >> "${OUTPUT_PREFIX}-GraphMat-BFS.out"
		"$GRAPHMATDIR/bin/BFS" "$DDIR/$d/$d.graphmat" $ROOT >> "${OUTPUT_PREFIX}-GraphMat-BFS.out"
		check_status $?
	done

	echo "Running GraphMat SSSP"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		echo "SSSP root: $ROOT" >> "${OUTPUT_PREFIX}-GraphMat-SSSP.out"
		"$GRAPHMATDIR/bin/SSSP" "$DDIR/$d/$d.graphmat" $ROOT >> "${OUTPUT_PREFIX}-GraphMat-SSSP.out"
		check_status $?
	done

	echo "Running Graphmat PageRank"
	# PageRank stops when none of the vertices change
	# GraphMat has been modified so alpha = 0.15
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GRAPHMATDIR/bin/PageRank" "$DDIR/$d/$d.graphmat" >> "${OUTPUT_PREFIX}-GraphMat-PR.out"
		check_status $?
	done

	# TODO: Currently wrong for facebook_combined
	echo "Running GraphMat TriangleCount"
	for dummy in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GRAPHMATDIR/bin/TriangleCounting"  "$DDIR/$d/$d.graphmat" >> "${OUTPUT_PREFIX}-GraphMat-TriangleCount.out"
		check_status $?
	done
fi

if [ "$RUN_POWERGRAPH" = 1 ]; then 
	echo "Running PowerGraph SSSP"
	rm -f "${OUTPUT_PREFIX}"-PowerGraph-{SSSP,PR,TC}.{out,err}
	# Note that PowerGraph also sends diagnostic output to stderr so we redirect that too.
	if [ "$OMP_NUM_THREADS" -gt 128 ]; then
		export GRAPHLAB_THREADS_PER_WORKER=128
		echo "WARNING: PowerGraph does not work with > 128 threads. Running on 128 threads."
	else
		export GRAPHLAB_THREADS_PER_WORKER=$OMP_NUM_THREADS
	fi
	for ROOT in $(cat "$DDIR/$d/${d}-${NRT}roots.v"); do
		"$POWERGRAPHDIR/release/toolkits/graph_analytics/sssp" --graph "$EDGELISTFILE" --format tsv --source $ROOT >> "${OUTPUT_PREFIX}-PowerGraph-SSSP.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-SSSP.err"
		check_status $?
	done

	echo "Running PowerGraph PageRank"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$POWERGRAPHDIR/release/toolkits/graph_analytics/pagerank" --graph "$EDGELISTFILE" --tol "$TOL" --format tsv >> "${OUTPUT_PREFIX}-PowerGraph-PR.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-PR.err"
		check_status $?
	done

	echo "Running PowerGraph TriangleCount"
	for dummy in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$POWERGRAPHDIR"/release/toolkits/graph_analytics/undirected_triangle_count --graph "$EDGELISTFILE" --format tsv >> "${OUTPUT_PREFIX}-PowerGraph-TriangleCount.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-TriangleCount.err"
		check_status $?
	done
fi

if [ "$RUN_GALOIS" = 1 ]; then 
	# Galois
	rm -f "${OUTPUT_PREFIX}"-Galois-{BFS,SSSP,PR}.out
	echo "Running Galois BFS"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GALOISDIR/apps/bfs/bfs" -noverify -startNode=$ROOT -t=$OMP_NUM_THREADS "$GALOIS_EDGELISTFILE" >> "${OUTPUT_PREFIX}-Galois-BFS.out" 2>> "${OUTPUT_PREFIX}-Galois-BFS.err"
		check_status $?
	done

	echo "Running Galois SSSP"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		# TODO: Adjust delta parameter -delta=<int>
		# Currently, SSSP throws an error when you try to use sg and not wsg file format.
		"$GALOISDIR"/apps/sssp/sssp -noverify -startNode=$ROOT -t=$OMP_NUM_THREADS  "$GALOIS_EDGELISTFILE" >> "${OUTPUT_PREFIX}-Galois-SSSP.out" 2>> "${OUTPUT_PREFIX}-Galois-SSSP.err"
		check_status $?
	done

	echo "Running Galois PageRank"
	# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
	# error = sum(|newPR - oldPR|)
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GALOISDIR"/apps/pagerank/pagerank -symmetricGraph -noverify -graphTranspose="$DDIR/$d/${d}-t.gr" "$GALOIS_EDGELISTFILE"  >> "${OUTPUT_PREFIX}-Galois-PR.out" 2>> "${OUTPUT_PREFIX}-Galois-PR.err"
		check_status $?
	done

	# No triangle count for Galois
fi

if [ -n "$COPY" ]; then
	rm "$COPY/$d"/*
	rmdir "$COPY/$d"
fi

echo Finished experiment at $(date)

