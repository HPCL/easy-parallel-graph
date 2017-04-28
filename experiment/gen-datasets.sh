#!/bin/bash
# Generate an unweighted, undirected Kronecker (RMAT) graph in the file formats
# for graph500, GraphMat, GraphBIG, and GAP
# for BFS, SSSP, and PageRank
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

# Steps to do this yourself (with a custom file)
# d=<your_prefix>
# Save your file to $DDIR/$d.e
# If it's a weighted edge list or edge list, that's fine.
# if [ $(awk '{print NF; exit}' "$DDIR/$d.e") -eq 2 ]; then
# 	echo "SRC,DEST" > "$DDIR/$d/edge.csv"
# 	awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$DDIR/$d.e" > "$DDIR/$d/$d.el"
# elif [ $(awk '{print NF; exit}' "$DDIR/$d.e") -eq 3 ]; then
# 	echo "SRC,DEST,WEIGHT" > "$DDIR/$d/edge.csv"
# 	awk '{printf "%d %d\n", ($1+1), ($2+1) $3}' "$DDIR/$d.e" > "$DDIR/$d/$d.wel"
# else
# 	echo "File format not recognized"
# 	exit 1
# fi
# sed 's/[:space:]+/,/' "$DDIR/$d.e" >> "$DDIR/$d/edge.csv"
# echo "ID" > "$DDIR/$d/vertex.csv"
# sed 's/[:space:]+/,/' "$DDIR/$d.v" >> "$DDIR/$d/vertex.csv"

mkdir -p "$DDIR"
export OMP_NUM_THREADS=32
NRT=64
GAPDIR="$LIBDIR/gapbs"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
if [ "$REAL" = 'yes' ]; then
	for d in $DATA_PREFIX; do
		echo Converting $d into the correct formats...
		mkdir -p "$DDIR/$d"
		# We convert to an integer because some systems store weights that way
		# We add 1 for GraphMat to ensure it's 1-indexed (adding 1 won't hurt)
		# TODO: SNAP format
		# Same as .el format, but lines beginning with # are comments.
		# Just do one trial to be the same as the rest of the experiments
		if [ $(awk '{print NF; exit}' "$DDIR/$d.e") -eq 2 ]; then
			echo "SRC,DEST" > "$DDIR/$d/edge.csv"
			awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$DDIR/$d.e" > "$DDIR/$d/$d.el"
			# Get the roots by running SSSP and making sure you can visit a good
			# number of vertices
			"$GAPDIR/sssp" -f "$DDIR/$d/$d.el" -n $(($NRT*2)) > tmp.log
			# GAP output is e.g. "took 382 iterations".
			# We don't want it to take 1 iteration.
		elif [ $(awk '{print NF; exit}' "$DDIR/$d.e") -eq 3 ]; then
			echo "SRC,DEST,WEIGHT" > "$DDIR/$d/edge.csv"
			awk '{printf "%d %d\n", ($1+1), ($2+1) $3}' "$DDIR/$d.e" > "$DDIR/$d/$d.wel"
			"$GAPDIR/sssp" -f "$DDIR/$d/$d.wel" -n $(($NRT*2)) > tmp.log
		else
			echo "File format not recognized"
			exit 1
		fi
		awk -v NRT=$NRT '/Source/{src=$2}/took [0-9]+ iterations/{if($2>1 && cnt<NRT){printf "%d\n", src; cnt++}}' tmp.log > "$DDIR/$d/$d-roots.v"
		rm tmp.log
		sed 's/[:space:]+/,/' "$DDIR/$d.e" >> "$DDIR/$d/edge.csv"
		echo "ID" > "$DDIR/$d/vertex.csv"
		sed 's/[:space:]+/,/' "$DDIR/$d.v" >> "$DDIR/$d/vertex.csv"
	done
else # synthetic
	# Generate graph (Graph500 can only save to its binary format)
	d="$DATA_PREFIX"
	mkdir -p "$DDIR/$d"
	"$GRAPH500DIR/make-edgelist" -s $S -o "$DDIR/$d.graph500" -r "$DDIR/$d.roots"
	# Convert to GAP format (edgelist)
	"$GRAPH500DIR/graph5002el" "$DDIR/$d.graph500" "$DDIR/$d.roots" "$DDIR/$d.el" "$DDIR/${d}-roots.v"
	# Sort the roots (mitigate that weird issue with GraphBIG not working for root > # vertices read)
	cat "$DDIR/${d}-roots.v" | sort -n > tmp.txt
	cp tmp.txt "$DDIR/${d}-roots.v"
	rm tmp.txt

	# Symmetrize (make undirected)
	"$GAPDIR/converter" -f "$DDIR/${d}.el" -s -e "$DDIR/${d}-undir.el"
	# Convert to GraphBIG format
	awk 'BEGIN{print "SRC,DEST"} {printf "%d,%d\n", $1, $2}' "$DDIR/${d}-undir.el" > "$DDIR/$d/edge.csv"
	echo ID > "$DDIR/$d/vertex.csv"
	cat "$DDIR/${d}-undir.el" | tr ' ' '\n' | sort -n | uniq >> "$DDIR/$d/vertex.csv"

	# Convert to GraphMat format
	# GraphMat requires edge weights---Just make them all 1 for the .1wel format
	# XXX: What happens when you remove selfloops and duplicated edges.
	awk '{printf "%d %d %d\n", ($1+1), ($2+1), 1}' "$DDIR/${d}.el" > "$DDIR/$d.1wel"
	awk '{printf "%d\n", ($1+1)}' "$DDIR/${d}-roots.v" > "$DDIR/${d}-roots.1v"
	# TODO: Do we really want it weighted?
	"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 --nvertices $(cat $DDIR/${d}.1wel | wc -l) "$DDIR/$d.1wel" "$DDIR/$d.graphmat"
fi

# TEST: Convert back to non-binary, see what we get
# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 1 --inputformat 0 --outputformat 1 --inputheader 1 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 "$DDIR/$d.graphmat" "$DDIR/$d.test.1wel"

