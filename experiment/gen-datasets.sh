#!/bin/bash
# Generate an unweighted, undirected Kronecker graph in the file formats for
# graph500, GraphMat, GraphBIG, and GAP
# for BFS [add other algorithms when ready]
# This only needs to be done once per scale.
# For example, with S=20 the structure will look like
# $DDIR/
#   kron-20.graph500
#   kron-20.roots
#   kron-20-roots.v
#   kron-20.el
#   kron-20-undir.el
#   kron-20/
#     vertex.csv
#     edge.csv

# NOTE: It is assumed the libraries in LIBDIR are already built.
#       This requires Graph500, GraphMat, and GAP
USAGE="usage: gen-datasets.sh [--libdir=<dir>] [--ddir=<dir>] <scale>
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets" # 2^{<scale>} = Number of vertices.
if [ -z "$1" ]; then
	echo $USAGE
	echo 'You may also need to set the variables *DIR in gen-datasets.sh'
	exit 2
fi
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
	echo 'Please provide <scale>'
	echo $USAGE
	exit 2
fi
S=$1
GAPDIR="$LIBDIR/gapbs"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
BASE_FN="kron-$S"

# Generate graph (Graph500 can only save to its binary format)
"$GRAPH500DIR/make-edgelist" -s $S -o "$DDIR/$BASE_FN.graph500" -r "$DDIR/$BASE_FN.roots"
# Convert to GAP format (edgelist)
"$GRAPH500DIR/graph5002el" "$DDIR/$BASE_FN.graph500" "$DDIR/$BASE_FN.roots" "$DDIR/$BASE_FN.el" "$DDIR/${BASE_FN}-roots.v"
# Sort the roots (mitigate that weird issue with GraphBIG not working for root > # vertices read)
cat "$DDIR/${BASE_FN}-roots.v" | sort -n > tmp.txt
cp tmp.txt "$DDIR/${BASE_FN}-roots.v"
rm tmp.txt

# Symmetrize (make undirected)
"$GAPDIR/converter" -f "$DDIR/${BASE_FN}.el" -s -e "$DDIR/${BASE_FN}-undir.el"
# Convert to GraphBIG format
mkdir -p "$DDIR/$BASE_FN"
awk 'BEGIN{print "SRC,DEST"} {printf "%d,%d\n", $1, $2}' "$DDIR/${BASE_FN}-undir.el" > "$DDIR/$BASE_FN/edge.csv"
echo ID > "$DDIR/$BASE_FN/vertex.csv"
cat "$DDIR/${BASE_FN}-undir.el" | tr ' ' '\n' | sort -n | uniq >> "$DDIR/$BASE_FN/vertex.csv"

# Convert to GraphMat format
# GraphMat requires edge weights---Just make them all 1 for the .1wel format
# XXX: What happens when you remove selfloops and duplicated edges.
awk '{printf "%d %d %d\n", ($1+1), ($2+1), 1}' "$DDIR/${BASE_FN}.el" > "$DDIR/$BASE_FN.1wel"
awk '{printf "%d\n", ($1+1)}' "$DDIR/${BASE_FN}-roots.v" > "$DDIR/${BASE_FN}-roots.1v"
"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 --nvertices $(cat $DDIR/${BASE_FN}.1wel | wc -l) "$DDIR/$BASE_FN.1wel" "$DDIR/$BASE_FN.graphmat"

# TEST: Convert back to non-binary, see what we get
# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 1 --inputformat 0 --outputformat 1 --inputheader 1 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 "$DDIR/$BASE_FN.graphmat" "$DDIR/$BASE_FN.test.1wel"

