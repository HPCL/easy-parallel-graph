#!/bin/bash
# Generate an unweighted, undirected Kronecker graph in the file formats for
# graph500, GraphBIG, and GAP [add other systems when ready]
# for BFS [add other algorithms when ready]
# This only needs to be done once per scale.
# For example, with S=20 the structure will look like
# $DDIR/
#   kron-20.graph500
#   kron-20.roots
#   kron-20-roots.v
#   kron-20.el
#   kron-20/
#     vertex.csv
#     edge.csv

# NOTE: These must be set before you run this script
# It is also assumed these are all built.
# The building instructions are available in the respective repositories.
GRAPH500DIR=
GRAPHMATDIR=
DDIR= # Where to save the dataset

USAGE="gen-datasets.sh <scale>"
S=$1
BASE_FN="kron-$S"

if [ -z "$1" ]; then
	echo $USAGE
	exit 2
fi
# Generate graph (Graph500 can only save to its binary format)
"$GRAPH500DIR/make-edgelist" -s $S -o "$DDIR/$BASE_FN.graph500" -r "$DDIR/$BASE_FN.roots"
# Convert to GAP format
"$GRAPH500DIR/graph5002el" "$DDIR/$BASE_FN.graph500" "$DDIR/$BASE_FN.roots" "$DDIR/$BASE_FN.el" "$DDIR/${BASE_FN}-roots.v"
# Convert to GraphBIG format
mkdir -p "$DDIR/$BASE_FN"
awk 'BEGIN{print "SRC,DEST"} {printf "%d,%d\n", $1, $2}' "$DDIR/$BASE_FN.el" > "$DDIR/$BASE_FN/edge.csv"
echo ID > "$DDIR/$BASE_FN/vertex.csv"
cat "$DDIR/$BASE_FN.el" | tr ' ' '\n' | sort -n | uniq >> "$DDIR/$BASE_FN/vertex.csv"

# GraphMat can be installed using the following commands on arya
#module load intel/17
#cd ~/graphalytics/GraphMat
#make
# Convert to GraphMat format
awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$DDIR/$BASE_FN.el" > "$DDIR/$BASE_FN.1el"
awk '{printf "%d\n", ($1+1)}' "$DDIR/${BASE_FN}-roots.v" > "$DDIR/${BASE_FN}-roots.1v"
"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 1 --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 "$DDIR/$BASE_FN.1el" "$DDIR/$BASE_FN.graphmat"

