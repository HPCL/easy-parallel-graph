#!/bin/bash
USAGE="usage: gen-datasets.sh [--libdir=<dir>] [--ddir=<dir>] -f=<fn>|<scale>
	You may either provide a filename or generate an RMAT graph with 2^<scale>
		vertices. The current filetypes supported are of the form
		<edge1> <edge2> one per line OR
		<edge1> <edge2> <weight> with an optional comment lines beginning with #
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets" # 2^{<scale>} = Number of vertices.
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
#     kron-20/
#     vertex.csv
#     edge.csv
# And likewise for the real datasets, replacing 'kron-20' as appropriate.
# The 6 real-world datasets which come with graphalytics:
# kgs.e dota-league.e cit-Patents.e com-friendster.e twitter_mpi.e wiki-Talk.e

# NOTE: It is assumed the libraries in LIBDIR are already built.
# this can be done with get-libraries.sh
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
		exit 0
	;;
	-f=*)
		FILE=${arg#*=}
		FILE_PREFIX=$(basename ${FILE%.*})
		shift
	;;
	*)	# Default
		# Do nothing
	esac
done
if [ -z "$FILE" ]; then
	if [ "$#" -lt 1 ]; then
		echo 'Please provide <scale> or -f=<filename>'
		echo $USAGE
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

mkdir -p "$DDIR"
export OMP_NUM_THREADS=32
NRT=64
GAPDIR="$LIBDIR/gapbs"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
# Real world datasets as provided by Graphalytics
if [ "$FILE_PREFIX" != "kron-$S" ]; then
	d="$FILE_PREFIX" # For convenience
	mkdir -p "$DDIR/$d"
	echo Converting $FILE into the correct formats...
	# If it's from SNAP then there may be some comments
	awk '!/^#/{print}' "$FILE" > "$DDIR/$d.e"
	cd $DDIR
	if [ ! -f "$d.v" ]; then
		echo "Creating $d.v..."
		cat  "$d.e" | tr '[:blank:]' '\n'| sort -n | uniq > $d.v
	fi
	nvertices=$(wc -l $d.v | awk '{print $1}')
	echo -n  "Checking whether weighted or unweighted..."
	if [ $(awk '{print NF; exit}' "$d.e") -eq 2 ]; then
		echo " unweighted."
		echo "SRC,DEST" > "$d/edge.csv"
		# Add 1 to ensure it's at least 1-indexed. It won't hurt.
		awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$d.e" > "$d.el"
		# Get the roots by running SSSP and making sure you can visit a good
		# number of vertices GAP output is e.g. "took 382 iterations".
		# We don't want it to take 1 iteration.
		echo "Getting roots."
		"$GAPDIR/sssp" -f "$d/$d.el" -n $(($NRT*2)) > tmp.log
		# XXX: Right now GraphMat doesn't write out to an unweighted graph. So we just create unit weights.
		"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 0 --outputedgeweights 2 --nvertices=$nvertices "$d.el" "$d.graphmat"
	elif [ $(awk '{print NF; exit}' "$d.e") -eq 3 ]; then
		echo " weighted."
		echo "SRC,DEST,WEIGHT" > "$d/edge.csv"
		awk '{printf "%d %d\n", ($1+1), ($2+1) $3}' "$d.e" > "$d.wel"
		echo "Getting roots."
		"$GAPDIR/sssp" -f "$d/$d.wel" -n $(($NRT*2)) > tmp.log
		"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 1 --outputedgeweights 1 --nvertices=$nvertices "$d.wel" "$d.graphmat"
	else
		echo "File format not recognized"
		exit 1
	fi
	awk -v NRT=$NRT '/Source/{src=$2}/took [0-9]+ iterations/{if($2>1 && cnt<NRT){printf "%d\n", src; cnt++}}' tmp.log > "$DDIR/$d/$d-roots.v"
	rm tmp.log
	sed 's/[:space:]+/,/' "$DDIR/$d.e" >> "$DDIR/$d/edge.csv"
	echo "ID" > "$DDIR/$d/vertex.csv"
	sed 's/[:space:]+/,/' "$DDIR/$d.v" >> "$DDIR/$d/vertex.csv"
else # synthetic
	# Generate graph (Graph500 can only save to its binary format)
	d="$FILE_PREFIX"
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
	cat "$DDIR/${d}-undir.el" | tr '[:blank:]' '\n' | sort -n | uniq >> "$DDIR/$d/vertex.csv"

	# Convert to GraphMat format
	# GraphMat requires edge weights---Just make them all 1 for the .1wel format
	# XXX: What happens when you remove selfloops and duplicated edges.
	awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$DDIR/${d}.el" > "$DDIR/$d.1el"
	awk '{printf "%d\n", ($1+1)}' "$DDIR/${d}-roots.v" > "$DDIR/${d}-roots.1v"
	nvertices=$(wc -l $DDIR/$d.v | awk '{print $1}')
	"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 --nvertices=$nvertices "$DDIR/$d.1el" "$DDIR/$d.graphmat"
fi
cd -

# TEST: Convert back to non-binary, see what we get
# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 1 --inputformat 0 --outputformat 1 --inputheader 1 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 "$DDIR/$d.graphmat" "$DDIR/$d.test.1wel"

