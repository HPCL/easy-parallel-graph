#!/bin/bash
# Runs all the experiments for a given scale and thread count.
# NOTE: Must have called gen-datasets with same <scale> beforehand.
# Current algorithms:
#   Breadth First Search, Single Source Shortest Paths, PageRank
# Current platforms:
#   GraphBIG, Graph500, GAP, GraphMat, PowerGraph (SSSP & PR only)
USAGE="usage: run-synthetic.sh [options] <scale> <num-threads>
	scale: 2^scale = number of vertices
	num-threads: number of threads, usually sets OMP_NUM_THREADS
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets
	--outdir: output directory. Default: ./output
	--num-roots: Number of roots to run search on or number of experiments
		to run. Largely determines runtime. Default: 32
	--copy-to=<tmpdir>: copy graphs to <tmpdir>, delete after experiment.
		Default: do not copy
	--rmat=<params>: Set a, b, c, d for RMAT parameters. These are
		space-separated, so you'll have to quote them. You
		can provide 3 or 4. For example, --rmat='0.5 0.2 0.2'.
		Default: '0.57 0.19 0.19 0.05'. If the default, expects graphs
		stored in kron-<scale>, otherwise kron-<scale>_<a>_<b>_<c>_<d>"

# The edge factor (number of edges per vertex) is the default of 16.
DDIR="$(pwd)/datasets" # Dataset directory
LIBDIR="$(pwd)/lib"
OUTDIR="$(pwd)/output"
NRT=32 # Number of roots
RMAT_PARAMS="0.57 0.19 0.19 0.05"
unset COPY # can copy to a faster, temporary filesystem
RUN_GRAPH500=1
RUN_GAP=1
RUN_GALOIS=1
RUN_GRAPHMAT=0
RUN_GRAPHBIG=1
RUN_POWERGRAPH=1

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
	--rmat=*)
		RMAT_PARAMS=${arg#*=}
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
	echo "$USAGE"
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
GALOISDIR="$LIBDIR/Galois-2.2.1/build/default"
FILE_PREFIX="kron-$S"
if ! [ "$RMAT_PARAMS" = "0.57 0.19 0.19 0.05" ]; then
	d="${FILE_PREFIX}_$(echo $RMAT_PARAMS | tr ' ' '_')"
else
	d="$FILE_PREFIX"
fi
OUTPUT_PREFIX="$OUTDIR/$d/${OMP_NUM_THREADS}t"
mkdir -p "$OUTDIR/$d"
if [ -n "$COPY" ]; then
	mkdir -p "$COPY/$d"
	cp $DDIR/$d/* "$COPY/$d"
	DDIR="$COPY"
	echo "Copied data to $DDIR"
fi

# Set some other variables used throughout the experiment
# PageRank is usually represented as a 32-bit float,
# so ~6e-8*nvertices is the minimum absolute error detectable
# We set alpha = 0.15 in the respective source codes.
# NOTE: GraphMat doesn't seem to compute iterations in the same way.
MAXITER=50 # Maximum iterations for PageRank
TOL=0.00000006
export SKIP_VALIDATION=1

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
		LASTCMD=${LASTCMD##;*echo }
		LASTCMD=${LASTCMD%%>*}
		echo "There was a problem with $(eval echo $LASTCMD)"
		exit 1
	fi 
}

echo Note: Files of the form
echo "${OUTPUT_PREFIX}-{GAP,GraphMat,PowerGraph,Galois}-{BFS,SSSP,PR,TC}.out"
echo get overwritten.

echo Starting experiment with $OMP_NUM_THREADS threads at $(date)

if [ "$RUN_GRAPH500" = 1 ]; then 
	echo -n "Running Graph500 BFS"
	#omp-csr/omp-csr -s $S -o "$DDIR/$d/$d.graph500" -r "$DDIR/$d/$d.roots"
	# ^ This isn't working, so just regenerate the data ^
	if [ "$OMP_NUM_THREADS" -gt 1 ]; then
		echo " with OpenMP"
		L=($RMAT_PARAMS)
		"$GRAPH500DIR/omp-csr/omp-csr" -a ${L[0]} -b ${L[1]} -c ${L[2]} -s $S > "${OUTPUT_PREFIX}-Graph500-BFS.out"
		check_status $? omp-csr
	else
		echo " with OpenMP"
		"$GRAPH500DIR/omp-csr/omp-csr" -a ${L[0]} -b ${L[1]} -c ${L[2]} -s $S > "${OUTPUT_PREFIX}-Graph500-BFS.out"
		check_status $? omp-csr
		# echo " sequentially"
		# seq-csr is slower than omp-csr with one thread
		# "$GRAPH500DIR/seq-csr/seq-csr" -s $S > "${OUTPUT_PREFIX}-Graph500-BFS.out"
	fi
fi

# GAP
if [ "$RUN_GAP" = 1 ]; then 
	rm -f "${OUTPUT_PREFIX}"-GAP-{BFS,SSSP,PR,TC}.out
	echo "Running GAP BFS"
	# It would be nice if you could read in a file for the roots
	# Just do one trial to be the same as the rest of the experiments
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GAPDIR"/bfs -r $ROOT -f "$DDIR/$d/$d.sg" -n 1 -s >> "${OUTPUT_PREFIX}-GAP-BFS.out"
		check_status $? bfs
	done

	echo "Running GAP SSSP"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		# Currently, SSSP throws an error when you try to use sg and not wsg file format.
		"$GAPDIR"/sssp -r $ROOT -f "$DDIR/$d/$d.el" -n 1 -s >> "${OUTPUT_PREFIX}-GAP-SSSP.out"
		check_status $? sssp
	done

	echo "Running GAP PageRank"
	# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
	# error = sum(|newPR - oldPR|)
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GAPDIR"/pr -f "$DDIR/$d/$d.sg" -i $MAXITER -t $TOL -n 1 >> "${OUTPUT_PREFIX}-GAP-PR.out"
		check_status $? pr
	done

	echo "Running GAP TriangleCount"
	"$GAPDIR"/tc -f "$DDIR/$d/$d.sg" -n $NRT >> "${OUTPUT_PREFIX}-GAP-TC.out"
	check_status $? tc
fi

# PowerGraph
if [ "$RUN_POWERGRAPH" = 1 ]; then 
	rm -f "${OUTPUT_PREFIX}"-PowerGraph-{SSSP,PR,TC}.{out,err}
	echo "Running PowerGraph SSSP"
	# Note that PowerGraph also sends diagnostic output to stderr so we redirect that too.
	if [ "$OMP_NUM_THREADS" -gt 128 ]; then
		export GRAPHLAB_THREADS_PER_WORKER=128
		echo "WARNING: PowerGraph does not work with > 128 threads. Running on 128 threads."
	else
		export GRAPHLAB_THREADS_PER_WORKER=$OMP_NUM_THREADS
	fi
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$POWERGRAPHDIR/release/toolkits/graph_analytics/sssp" --graph "$DDIR/$d/$d.el" --format tsv --source $ROOT >> "${OUTPUT_PREFIX}-PowerGraph-SSSP.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-SSSP.err"
		check_status $? graph_analytics/sssp
	done

	echo "Running PowerGraph PageRank"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$POWERGRAPHDIR/release/toolkits/graph_analytics/pagerank" --graph "$DDIR/$d/$d.el" --tol "$TOL" --format tsv >> "${OUTPUT_PREFIX}-PowerGraph-PR.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-PR.err"
		check_status $? graph_analytics/pagerank
	done

	echo "Running PowerGraph TriangleCount"
	for dummy in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$POWERGRAPHDIR"/release/toolkits/graph_analytics/undirected_triangle_count --graph "$DDIR/$d/$d.el" --format tsv >> "${OUTPUT_PREFIX}-PowerGraph-TC.out" 2>> "${OUTPUT_PREFIX}-PowerGraph-TC.err"
		check_status $? undirected_triangle_count
	done
fi

# GraphMat
if [ "$RUN_GRAPHMAT" = 1 ]; then 
	rm -f "${OUTPUT_PREFIX}"-GraphMat-{BFS,SSSP,PR}.out
	echo "Running GraphMat BFS"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.1v"); do
		echo "BFS root: $ROOT" >> "${OUTPUT_PREFIX}-GraphMat-BFS.out"
		"$GRAPHMATDIR/bin/BFS" "$DDIR/$d/$d.graphmat" $ROOT >> "${OUTPUT_PREFIX}-GraphMat-BFS.out"
		check_status $? 'bin/BFS'
	done

	echo "Running GraphMat SSSP"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.1v"); do
		echo "SSSP root: $ROOT" >> "${OUTPUT_PREFIX}-GraphMat-SSSP.out"
		"$GRAPHMATDIR/bin/SSSP" "$DDIR/$d/$d.graphmat" $ROOT >> "${OUTPUT_PREFIX}-GraphMat-SSSP.out"
		check_status $? bin/SSSP
	done

	echo "Running GraphMat PageRank"
	# PageRank stops when none of the vertices change
	# GraphMat has been modified so alpha = 0.15
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.1v"); do
		"$GRAPHMATDIR/bin/PageRank" "$DDIR/$d/$d.graphmat" >> "${OUTPUT_PREFIX}-GraphMat-PR.out"
		check_status $? bin/PageRank
	done

	# TODO: Triangle Counting gives different answers on every platform
	echo "Running GraphMat TriangleCount"
	for dummy in $(head -n $NRT "$DDIR/$d/$d-roots.1v"); do
		"$GRAPHMATDIR/bin/TriangleCounting" "$DDIR/$d/$d.graphmat" >> "${OUTPUT_PREFIX}-GraphMat-TC.out"
		check_status $? bin/TriangleCounting
	done
fi

# GraphBIG
if [ "$RUN_GRAPHBIG" = 1 ]; then 
	rm -f "${OUTPUT_PREFIX}"-GraphBIG-{BFS,SSSP,PR,TC}.out
	echo "Running GraphBIG BFS"
	# For this, one needs a vertex.csv file and and an edge.csv.
	head -n $NRT "$DDIR/$d/$d-roots.v" > "$DDIR/$d/$d-${NRT}roots.v"
	"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/$d" --rootfile "$DDIR/$d/$d-${NRT}roots.v" --threadnum $OMP_NUM_THREADS > "${OUTPUT_PREFIX}-GraphBIG-BFS.out"
	check_status $? bench_BFS/bfs

	echo "Running GraphBIG SSSP"
	"$GRAPHBIGDIR/benchmark/bench_shortestPath/sssp" --dataset "$DDIR/$d" --rootfile "$DDIR/$d/$d-${NRT}roots.v" --threadnum $OMP_NUM_THREADS > "${OUTPUT_PREFIX}-GraphBIG-SSSP.out"
	check_status $? bench_shortestPath/sssp

	echo "Running GraphBIG PageRank"
	# The original GraphBIG has --quad = sqrt(sum((newPR - oldPR)^2))
	# GraphBIG error has been modified to now be sum(|newPR - oldPR|)
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GRAPHBIGDIR/benchmark/bench_pageRank/pagerank" --dataset "$DDIR/$d" --maxiter $MAXITER --quad $TOL --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-PR.out"
		check_status $? bench_pageRank/pagerank
	done

	echo "Running GraphBIG TriangleCount"
	for dummy in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GRAPHBIGDIR/benchmark/bench_triangleCount/tc" --dataset "$DDIR/$d" --threadnum $OMP_NUM_THREADS >> "${OUTPUT_PREFIX}-GraphBIG-TC.out"
		check_status $? bench_triangleCount/tc
	done
fi

# Galois
if [ "$RUN_GALOIS" = 1 ]; then 
	rm -f "${OUTPUT_PREFIX}"-Galois-{BFS,SSSP,PR}.out
	echo "Running Galois BFS"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GALOISDIR/apps/bfs/bfs" -noverify -startNode=$ROOT -t=$OMP_NUM_THREADS "$DDIR/$d/$d.gr" > "${OUTPUT_PREFIX}-Galois-BFS.out"
		check_status $? bfs/bfs
	done

	echo "Running Galois SSSP"
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		# TODO: Adjust delta parameter -delta=<int>
		# Currently, SSSP throws an error when you try to use sg and not wsg file format.
		"$GALOISDIR"/apps/sssp/sssp -noverify -startNode=$ROOT -t=$OMP_NUM_THREADS  "$DDIR/$d/$d.gr" >> "${OUTPUT_PREFIX}-Galois-SSSP.out"
		check_status $? sssp/sssp
	done

	echo "Running Galois PageRank"
	# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
	# error = sum(|newPR - oldPR|)
	for ROOT in $(head -n $NRT "$DDIR/$d/$d-roots.v"); do
		"$GALOISDIR"/apps/pagerank/pagerank -symmetricGraph -noverify -graphTranspose="$DDIR/$d/$d-t.gr" "$DDIR/$d/$d.gr" >> "${OUTPUT_PREFIX}-Galois-PR.out"
		check_status $? pagerank/pagerank
	done

	# No triangle count for Galois
fi

if [ -n "$COPY" ]; then
	rm $COPY/$d/*
	rmdir "$COPY/$d"
fi
echo Finished experiment at $(date)

