#!/bin/bash
# Runs all the experiments
# Current algorithms: BFS
# Current platforms: GraphBIG, Graph500, GAP
# This can be run with either 
# ./run-experiment
# or
# qsub run-experiment.sh

# NOTE: YOU MUST SET THE REPOSITORY LOCATIONS AND MODULES TO LOAD
# It is assumed these are all built and the gen-dataset.sh script has been run.
# The building instructions are available in the respective repositories.
# Here, edge factor (number of edges per vertex) is the default of 16.
S=20 # Scale. 2^S = Number of vertices.
DDIR=/home/users/spollard/graphalytics/all-datasets/gabb17 # Dataset directory
GAPDIR=/home/users/spollard/gap/gapbs
GRAPHBIGDIR=/home/users/spollard/gap/graphBIG
GRAPH500DIR=/home/users/spollard/graph500

# Load all the modules here
# module load mpi/mpich-3.1_gcc-4.9

# qsub scheduling options
#PBS -N graph_experiments
#PBS -q generic
#PBS -l nodes=1:ppn=12,mem=32gb
#PBS -o /home8/spollard/compare/graph_experiments.out
#PBS -e /home8/spollard/compare/graph_exeriments.err
# Other options: -M email, -m when to send email- abe, -X X11 forwarding

# Run for GAP for each root
# It would be nice if you could read in a file for the roots
while read ROOT; do
	"$GAPDIR"/bfs -r $ROOT -f "$DDIR/kron-${S}.el"
done <"$DDIR/kron-${S}-roots.v"

# Run the Graph500 OpenMP benchmark
# This isn't working, so just regenerate the data
#omp-csr/omp-csr -s $S -o "$DDIR/kron-${S}.graph500" -r "$DDIR/kron-${S}.roots"
"$GRAPH500DIR/omp-csr/omp-csr" -s $S 

# Run the GraphBIG Benchmark
# For this, one needs a vertex.csv file and and an edge.csv.
while read ROOT; do
	"$GRAPHBIGDIR/benchmark/bench_BFS/bfs" --dataset "$DDIR/kron-${S}" --root $ROOT
done <"$DDIR/kron-${S}-roots.v"

