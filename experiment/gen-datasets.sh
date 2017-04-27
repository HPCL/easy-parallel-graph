#!/bin/bash
# Generate an unweighted, undirected Kronecker graph in the file formats for
# graph500, GraphMat, GraphBIG, and GAP
# for BFS [add other algorithms when ready]
# This only needs to be done once per scale.
# For example, with S=20 the structure will look like
# $DDIR/
#   kron-20/
#     kron-20.graph500
#     kron-20.roots
#     kron-20-roots.v
#     kron-20.el
#     kron-20-undir.el
#     kron-20/
#     vertex.csv
#     edge.csv
# And likewise for the real datasets, replacing 'kron-20' as appropriate.

# NOTE: It is assumed the libraries in LIBDIR are already built.
#       This requires Graph500, GraphMat, and GAP
USAGE="usage: gen-datasets.sh [--libdir=<dir>] [--ddir=<dir>] <scale>
	<scale> may be either an integer or the string 'real'
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets" # 2^{<scale>} = Number of vertices.
if [ -z "$1" ]; then
	echo "$USAGE"
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
case $1 in
[1-9]|[1-9][0-9]*) # scale between 1--99 is robust enough
	S=$1
	DATA_PREFIX="kron-$S"
	REAL='no'
;;
real*)
	DATA_PREFIX="dota-league cit-Patents"
	REAL='yes'
;;
*) # Default
	echo "<scale> must be either a positive number or 'real' (without quotes)"
	exit 2
;;
esac

export OMP_NUM_THREADS=32
GAPDIR="$LIBDIR/gapbs"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
if [ "$REAL" = 'yes' ]; then
	for d in $DATA_PREFIX; do
		echo Converting $d into the correct formats...
		mkdir -p "$DDIR/$d"
		# We convert to an integer because some systems store weights that way
		# We add 1 for GraphMat to ensure it's 1-indexed (adding 1 won't hurt)
		awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$DDIR/$d.e" > "$DDIR/$d/$d.1wel"
		if [ $(awk '{print NF; exit}' "$DDIR/$d.e") -eq 2 ]; then
			echo "SRC,DEST" > "$DDIR/$d/edge.csv"
		elif [ $(awk '{print NF; exit}' "$DDIR/$d.e") -eq 3 ]; then
			echo "SRC,DEST,WEIGHT" > "$DDIR/$d/edge.csv"
		else
			echo "File format not recognized"
			exit 1
		fi
		sed 's/[:space:]+/,/' "$DDIR/$d.e" >> "$DDIR/$d/edge.csv"
		echo "ID" > "$DDIR/$d/vertex.csv"
		sed 's/[:space:]+/,/' "$DDIR/$d.v" >> "$DDIR/$d/vertex.csv"
		# Get the roots by running SSSP and making sure you can visit a good
		# number of vertices
		"$GAPDIR/sssp" -f "$DDIR/$d/$d.1wel" -n $(($NRT*2)) > tmp.log
		# GAP output is e.g. "took 382 iterations".
		# We don't want it to take 1 iteration.
		awk -v NRT=$NRT '/Source/{src=$2}/took [0-9]+ iterations/{if($2>1 && cnt<NRT){printf "%d\n", src; cnt++}}' tmp.log > "$DDIR/$d/$d-roots.v"
		rm tmp.log
	done
else # synthetic
	# Generate graph (Graph500 can only save to its binary format)
	d="$DATA_PREFIX"
	mkdir -p "$DDIR/$BASE_FN"
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
	awk 'BEGIN{print "SRC,DEST"} {printf "%d,%d\n", $1, $2}' "$DDIR/${BASE_FN}-undir.el" > "$DDIR/$BASE_FN/edge.csv"
	echo ID > "$DDIR/$BASE_FN/vertex.csv"
	cat "$DDIR/${BASE_FN}-undir.el" | tr ' ' '\n' | sort -n | uniq >> "$DDIR/$BASE_FN/vertex.csv"

	# Convert to GraphMat format
	# GraphMat requires edge weights---Just make them all 1 for the .1wel format
	# XXX: What happens when you remove selfloops and duplicated edges.
	awk '{printf "%d %d %d\n", ($1+1), ($2+1), 1}' "$DDIR/${BASE_FN}.el" > "$DDIR/$BASE_FN.1wel"
	awk '{printf "%d\n", ($1+1)}' "$DDIR/${BASE_FN}-roots.v" > "$DDIR/${BASE_FN}-roots.1v"
	"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 --nvertices $(cat $DDIR/${BASE_FN}.1wel | wc -l) "$DDIR/$BASE_FN.1wel" "$DDIR/$BASE_FN.graphmat"
fi

# TEST: Convert back to non-binary, see what we get
# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 1 --inputformat 0 --outputformat 1 --inputheader 1 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 "$DDIR/$BASE_FN.graphmat" "$DDIR/$BASE_FN.test.1wel"

