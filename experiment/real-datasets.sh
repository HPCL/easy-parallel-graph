#!/bin/bash
# Runs all the experiments for a given thread count on the available datasets
# Current algorithms:
#   Breadth First Search, Single Source Shortest Paths, PageRank
# Current platforms:
#   GraphBIG, Graph500, GAP, GraphMat, PowerGraph (SSSP & PR only)
# Recommended usage for bash
#   ./run-experiment $T > outreal-${T}.log 2> outreal-${T}.err &
#   disown %<jobnum> # This can be found out using jobs
USAGE="usage: real-datasets.sh <num-threads>"

# Say where the packages are located
# NOTE: YOU MUST SET THE REPOSITORY LOCATIONS AND MODULES TO LOAD
# It is assumed these are all built and the gen-dataset.sh script has been run.
# The building instructions are available in the respective repositories.
# Here, edge factor (number of edges per vertex) is the default of 16.
DDIR=
DATA="dota-league" # Just one
GAPDIR=
GRAPHBIGDIR=
GRAPH500DIR=
GRAPHMATDIR=
POWERGRAPHDIR=

# Set some other variables used throughout the experiment
# PageRank is usually represented as a 32-bit float,
# so ~6e-8*nvertices is the minimum absolute error detectable
# We set alpha = 0.15 in the respective source codes.
# NOTE: GraphMat doesn't seem to compute iterations in the same way.
MAXITER=50 # Maximum iterations for PageRank
TOL=0.00000006
NRT=32 # Number of roots
export SKIP_VALIDATION=1
if [ "$#" -ne 1 -o "$1" = "-h" -o "$1" = "--help" ]; then
	echo "$USAGE"
	exit 2
fi
export OMP_NUM_THREADS=$1

# Load all the modules here
module load intel/17

# Build notes for arya:
# see run-experiment.sh

# echo Converting $DATA into the correct formats...
# # We convert to an integer because some systems store weights that way
# We add 1 for GraphMat to ensure it's 1-indexed (adding 1 won't hurt)
awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$DDIR/$DATA.e" > "$DDIR/$DATA.wel"
# GraphBIG already exists for dota-league (for some reason)
# TODO: Add GraphBIG conversion
# Get the roots by running BFS and making sure you can visit a good number of vertices
# XXX: May want to run on many roots so we can pare down the list to exactly $NRT
"$GAPDIR"/sssp -f "$DDIR/$DATA.wel" -n $NRT > tmp.log
# GAP output is, e.g. "took 382 iterations". We don't want it to take 1 iteration.
awk -v NRT=$NRT '/Source/{src=$2}/took [0-9]+ iterations/{if($2>1 && cnt<NRT){printf "%d\n", src; cnt++}}' tmp.log > "$DDIR/$DATA-roots.v"
rm tmp.log


# GraphMat doesn't currently work
# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --edgeweighttype 1 --inputedgeweights 1 --outputedgeweights 1 "$DDIR/$DATA.wel" "$DDIR/$DATA.graphmat"
# # Run GraphMat PageRank
# # PageRank stops when none of the vertices change
# # GraphMat has been modified so alpha = 0.15
# for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
# 	"$GRAPHMATDIR/bin/PageRank" "$DDIR/$DATA.graphmat"
# done
# 
# # Run the GraphMat SSSP
# for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
# 	echo "SSSP root: $ROOT"
# 	"$GRAPHMATDIR/bin/SSSP" "$DDIR/$DATA.graphmat" $ROOT
# done
# 
# # Run the GraphMat BFS
# for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
# 	echo "BFS root: $ROOT"
# 	"$GRAPHMATDIR/bin/BFS" "$DDIR/$DATA.graphmat" $ROOT
# done
# 
# # Run PowerGraph PageRank
# for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
# 	"$POWERGRAPHDIR/release/toolkits/graph_analytics/pagerank" --graph "$DDIR/$DATA.wel" --tol "$TOL" --format tsv
# done

echo Starting experiment at $(date)
# Run for GAP BFS
# It would be nice if you could read in a file for the roots
# Just do one trial to be the same as the rest of the experiments
for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
	"$GAPDIR"/bfs -r $ROOT -f "$DDIR/$DATA.wel" -n 1
done

# Run the GraphBIG BFS
# For this, one needs a vertex.csv file and and an edge.csv.
for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
	"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/$DATA" --root $ROOT --threadnum $OMP_NUM_THREADS
done


# Run the GAP SSSP for each root
for ROOT in $(head -n $NRT "$DDIR/$DATA.v"); do
	"$GAPDIR"/sssp -r $ROOT -f "$DDIR/$DATA.wel" -n 1
done

# Run the GraphBIG SSSP
for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
	"$GRAPHBIGDIR/benchmark/bench_shortestPath/sssp" --dataset "$DDIR/$DATA" --root $ROOT --threadnum $OMP_NUM_THREADS
done


# Run PowerGraph SSSP
if [ "$OMP_NUM_THREADS" -gt 64 ]; then
    export GRAPHLAB_THREADS_PER_WORKER=64
	echo "WARNING: PowerGraph does not work with > 64 threads. Running on 64 threads."
else
    export GRAPHLAB_THREADS_PER_WORKER=$OMP_NUM_THREADS
fi
for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
	"$POWERGRAPHDIR/release/toolkits/graph_analytics/sssp" --graph "$DDIR/$DATA.wel" --format tsv --source $ROOT
done

# PageRank Note: ROOT is a dummy variable to ensure the same # of trials
# Run GAP PageRank
# error = sum(|newPR - oldPR|)
for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
	"$GAPDIR"/pr -f "$DDIR/$DATA.wel" -i $MAXITER -t $TOL -n 1
done

# Run GraphBIG PageRank
# The original GraphBIG has --quad = sqrt(sum((newPR - oldPR)^2))
# GraphBIG error has been modified to now be sum(|newPR - oldPR|)
for ROOT in $(head -n $NRT "$DDIR/$DATA-roots.v"); do
	"$GRAPHBIGDIR/benchmark/bench_pageRank/pagerank" --dataset "$DDIR/$DATA" --maxiter $MAXITER --quad $TOL --threadnum $OMP_NUM_THREADS
done

echo Finished experiment at $(date)

