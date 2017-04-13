#!/bin/bash
# Runs all the experiments for a given scale and thread count.
# NOTE: Must have called gen-datasets with same <scale> beforehand.
# Current algorithms:
#   Breadth First Search, Single Source Shortest Paths, PageRank
# Current platforms:
#   GraphBIG, Graph500, GAP, GraphMat, PowerGraph (SSSP & PR only)
# Recommended usage for bash
#   ./run-experiment $S $T > out${S}-${T}.log 2> out${S}-${T}.err &
#   disown %<jobnum> # This can be found out using jobs
USAGE="usage: run-experiment.sh [--libdir=<dir>] [--ddir=<dir>] <scale> <num-threads>
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets" # 2^{<scale>} = Number of vertices.

# It is assumed these are all built and the gen-dataset.sh script has been run.
# The edge factor (number of edges per vertex) is the default of 16.
# Build notes for each system
# cd $LIBDIR
# GAP:
# 	git clone https://github.com/sampollard/gapbs.git
# 	cd gapbs; make
# GraphBIG: 
# 	git clone https://github.com/sampollard/graphBIG.git
#   cd graphBIG; make
# 	cd GraphBIG/benchmark
# 	make clean all
# GraphMat:
# 	module load intel/17
# 	git clone https://github.com/sampollard/GraphMat.git
# 	cd GraphMat; make 
# Graph500:
# 	git clone https://github.com/sampollard/graph500.git
#   cd graph500; make
# PowerGraph:
#	# NOTE: Shared memory only!
# 	NUM_CORES=$(grep -c ^processor /proc/cpuinfo)
# 	if [ "$NUM_CORES" -gt 64 ]; then
# 	    export GRAPHLAB_THREADS_PER_WORKER=64
# 	else
# 	    export GRAPHLAB_THREADS_PER_WORKER=$NUM_CORES
# 	fi
# 	git clone https://github.com/sampollard/PowerGraph
# 	cd PowerGraph
# 	./configure --no_jvm
#   cd release/toolkits/graph_analytics
#   make -j4
# PBGL: (not used here)
# 	module load boost/boost_1_62_0_gcc-5
# 	mpicxx -I/usr/local/packages/boost/1_62_0/gcc-5/include -L/usr/local/packages/boost/1_62_0/gcc-5/lib -o pbMST pbMST.cpp -lboost_graph_parallel -lboost_mpi -lboost_serialization -lboost_system
# 	export LD_LIBRARY_PATH=/usr/local/packages/boost/1_62_0/gcc-5/lib

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

# qsub scheduling options
#PBS -N graph_experiments
#PBS -q generic
#PBS -l nodes=1:ppn=12,mem=32gb
#PBS -o /home8/spollard/compare/graph_experiments.out
#PBS -e /home8/spollard/compare/graph_exeriments.err
# Other options: -M email, -m when to send email- abe, -X X11 forwarding

echo Starting experiment at $(date)

# Run the Graph500 BFS: OpenMP
# This isn't working, so just regenerate the data
#omp-csr/omp-csr -s $S -o "$DDIR/kron-${S}.graph500" -r "$DDIR/kron-${S}.roots"
if [ "$OMP_NUM_THREADS" -gt 1 ]; then
	"$GRAPH500DIR/omp-csr/omp-csr" -s $S 
else
	"$GRAPH500DIR/seq-csr/seq-csr" -s $S 
fi

# Run for GAP BFS
# It would be nice if you could read in a file for the roots
# Just do one trial to be the same as the rest of the experiments
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
	"$GAPDIR"/bfs -r $ROOT -f "$DDIR/kron-${S}.el" -n 1 -s
done

# Run the GraphBIG BFS
# For this, one needs a vertex.csv file and and an edge.csv.
# for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
# 	"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/kron-${S}" --root $ROOT --threadnum $OMP_NUM_THREADS
# done
head -n $NRT "$DDIR/kron-${S}-roots.v" > "$DDIR/kron-${S}-${NRT}roots.v"
"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/kron-${S}" --rootfile "$DDIR/kron-${S}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS

# Run the GraphMat BFS
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.1v"); do
	echo "BFS root: $ROOT"
	"$GRAPHMATDIR/bin/BFS" "$DDIR/kron-${S}.graphmat" $ROOT
done

# Run the GAP SSSP for each root
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
	"$GAPDIR"/sssp -r $ROOT -f "$DDIR/kron-${S}.el" -n 1 -s
done

# Run the GraphBIG SSSP
# for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
# 	"$GRAPHBIGDIR/benchmark/bench_shortestPath/sssp" --dataset "$DDIR/kron-${S}" --rootfile "$DDIR/kron-${S}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS
# done
"$GRAPHBIGDIR/benchmark/bench_shortestPath/sssp" --dataset "$DDIR/kron-${S}" --rootfile "$DDIR/kron-${S}-${NRT}roots.v" --threadnum $OMP_NUM_THREADS

# Run the GraphMat SSSP
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.1v"); do
	echo "SSSP root: $ROOT"
	"$GRAPHMATDIR/bin/SSSP" "$DDIR/kron-${S}.graphmat" $ROOT
done

# Run PowerGraph SSSP
if [ "$OMP_NUM_THREADS" -gt 64 ]; then
    export GRAPHLAB_THREADS_PER_WORKER=64
	echo "WARNING: PowerGraph does not work with > 64 threads. Running on 64 threads."
else
    export GRAPHLAB_THREADS_PER_WORKER=$OMP_NUM_THREADS
fi
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/sssp" --graph "$DDIR/kron-${S}.el" --format tsv --source $ROOT
done

# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
# Run GAP PageRank
# error = sum(|newPR - oldPR|)
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
	"$GAPDIR"/pr -f "$DDIR/kron-${S}.el" -i $MAXITER -t $TOL -n 1
done

# Run GraphBIG PageRank
# The original GraphBIG has --quad = sqrt(sum((newPR - oldPR)^2))
# GraphBIG error has been modified to now be sum(|newPR - oldPR|)
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
	"$GRAPHBIGDIR/benchmark/bench_pageRank/pagerank" --dataset "$DDIR/kron-${S}" --maxiter $MAXITER --quad $TOL --threadnum $OMP_NUM_THREADS
done

# Run GraphMat PageRank
# PageRank stops when none of the vertices change
# GraphMat has been modified so alpha = 0.15
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.1v"); do
	"$GRAPHMATDIR/bin/PageRank" "$DDIR/kron-${S}.graphmat"
done

# Run PowerGraph PageRank
for ROOT in $(head -n $NRT "$DDIR/kron-${S}-roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/pagerank" --graph "$DDIR/kron-${S}.el" --tol "$TOL" --format tsv
done

echo Finished experiment at $(date)
