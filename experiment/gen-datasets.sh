#!/bin/bash
USAGE="usage: gen-datasets.sh [--libdir=<dir>] [--ddir=<dir>] -f=<fn>|<scale>
	You may either provide a filename or generate an RMAT graph with 2^<scale>
		vertices. The current filetypes supported are of the form
		<edge1> <edge2> one per line OR
		<edge1> <edge2> <weight> with an optional comment lines beginning with #
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets"
# Generate an unweighted, undirected Kronecker (RMAT) graph in the file formats
# for graph500, GraphMat, GraphBIG, and GAP
# for BFS, SSSP, and PageRank
# This only needs to be done once per scale.
# For example, with S=20 the structure will look like
# $DDIR/
#     kron-20/
#         kron-20.graph500
#         kron-20.roots
#         kron-20-roots.v
#         kron-20-roots.1v
#         kron-20.el
#         kron-20.1el
#         kron-20-undir.el
#         kron-20.graphmat
#         kron-20.vgr # TODO: Test if vgr or gr can work
#         vertex.csv
#         edge.csv
# If you have a real dataset with filename pre.whatever;
# extensions of .wel and .gr if weighted, .el and .vgr if unweighted.
# $DDIR/
#     pre.e
#     pre.v
#     pre/
#         pre.graphmat
#         pre.roots
#         pre-roots.v
#         pre.[w]el
#         pre.[v]gr
#         pre.1el
#         vertex.csv
#         edge.csv
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
export OMP_NUM_THREADS=64
NRT=64
GAPDIR="$LIBDIR/gapbs"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
GALOISDIR="$LIBDIR/Galois-2.2.1/build/default"
### Real world datasets as provided by Graphalytics
if [ "$FILE_PREFIX" != "kron-$S" ]; then
	d="$FILE_PREFIX" # For convenience
	mkdir -p "$DDIR/$d"
	echo Converting $FILE into the correct formats...
	# If it's from SNAP then there may be some comments
	if [ ! -f "$DDIR/$d.e" ]; then
		if [ ! -f "$FILE" ]; then
			echo "Cannot find file $FILE relative from $(pwd)"
			exit 1
		fi
		awk '!/^#/{print}' "$FILE" > "$DDIR/$d.e"
	fi
	OLDPWD=$(pwd)
	cd $DDIR
	if [ ! -f "$d.v" ] || [ $(wc -l "$d.v") -gt 0 ]; then
		echo "Creating $d.v..."
		cat  "$d.e" | tr '[:blank:]' '\n'| sort -n | uniq > $d.v
	fi
	# nvertices is a bit of a misnomer; it should actually be "max vertex id"
	nvertices=$(( $(sort -n "$d.v" | tail -n 1) + 1))
	echo -n  "Checking whether $d.e is weighted or unweighted..."
	if [ $(awk '{print NF; exit}' "$d.e") -eq 2 ]; then
		echo " unweighted."
		echo "SRC,DEST" > "$d/edge.csv"
		# Add 1 to ensure it's at least 1-indexed. It won't hurt.
		awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$d.e" > "$d/$d.el"
		# Get the roots by running SSSP and making sure you can visit a good
		# number of vertices GAP output is e.g. "took 382 iterations".
		# We don't want it to take 1 iteration.
		echo "Getting roots."
		"$GAPDIR/sssp" -f "$d/$d.el" -n $(($NRT*2)) > tmp.log
		# We write a serialized graph to speed up GAP
		"$GAPDIR/converter" -s -f "$d/$d.el" -b "$d/$d.sg"
		# GraphMat doesn't write out an unweighted graph. So we have output unit edge weights.
		"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 0 --outputedgeweights 2 --nvertices $nvertices "$d/$d.el" "$d/$d.graphmat"

		# Convert to Galois format
		echo "Galois file format for real world graphs currently unsupported." # TODO
	elif [ $(awk '{print NF; exit}' "$d.e") -eq 3 ]; then
		echo " weighted. Weighted graphs are currently not supported because of a bug in GraphMat."
		echo "SRC,DEST,WEIGHT" > "$d/edge.csv"
		awk '{printf "%d %d %s\n", ($1+1), ($2+1), $3}' "$d.e" > "$d/$d.wel"
		awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$d.e" > "$d/$d.el" # For GraphMat
		echo "Getting roots."
		"$GAPDIR/sssp" -f "$d/$d.el" -n $(( $NRT * 2 )) > tmp.log
		# TODO: Use this in real-datasets, change WeightT to float if need be and recompile GAPBS
		"$GAPDIR/converter" -s -f "$d/$d.wel" -b "$d/$d.wsg"
		# We make no assumptions so we output double precision edge weights
		# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 1 --outputedgeweights 0 --edgeweighttype 1 --nvertices $nvertices "$d/$d.wel" "$d/$d.graphmat"
		"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 0 --outputedgeweights 2 --nvertices $nvertices "$d/$d.el" "$d/$d.graphmat"
		# Convert to Galois format
		echo "Galois file format for real world graphs currently unsupported." # TODO
	else
		echo "File format not recognized"
		cd "$OLDPWD"
		exit 1
	fi
	awk -v NRT=$NRT '/Source/{src=$2}/took [0-9]+ iterations/{if($2>1 && cnt<NRT){printf "%d\n", src; cnt++}}' tmp.log > "$DDIR/$d/$d-roots.v"
	rm tmp.log
	sed 's/[:space:]+/,/' "$DDIR/$d.e" >> "$DDIR/$d/edge.csv"
	echo "ID" > "$DDIR/$d/vertex.csv"
	sed 's/[:space:]+/,/' "$DDIR/$d.v" >> "$DDIR/$d/vertex.csv"
### Synthetic datasets to the Graph500 specification
else
	# Generate graph (Graph500 can only save to its binary format)
	d="$FILE_PREFIX"
	mkdir -p "$DDIR/$d"
	# FIXME: make-edgelist only generates files at most 2.0Gb
	# "$GRAPH500DIR/make-edgelist" -s $S -o "$DDIR/$d/$d.graph500" -r "$DDIR/$d/$d.roots"

	# Convert to edgelist
	#"$GRAPH500DIR/graph5002el" "$DDIR/$d/$d.graph500" "$DDIR/$d/$d.roots" "$DDIR/$d/$d.el" "$DDIR/$d/${d}-roots.v" # TODO
	"$GAPDIR/converter" -g $S -e "$DDIR/$d/$d.el"

	# Symmetrize (make undirected)
	"$GAPDIR/converter" -g $S -s -e "$DDIR/$d/${d}-undir.el"

	# Convert to GAP serialized format
	"$GAPDIR/converter" -g $S -s -b "$DDIR/$d/$d.sg"

	# Generate roots (usually graph500 does this but it doesn't work for scale > 22)
	"$GAPDIR/bfs" -n $NRT -f "$DDIR/$d/$d.sg" | awk '/Source/{print $2}' > "$DDIR/$d/${d}-roots.v"

	# Sort the roots (mitigate that weird issue with GraphBIG not working for root > # vertices read)
	cat "$DDIR/$d/${d}-roots.v" | sort -n > tmp.txt
	cp tmp.txt "$DDIR/$d/${d}-roots.v"
	rm tmp.txt

	# Convert to GraphBIG format
	awk 'BEGIN{print "SRC,DEST"} {printf "%d,%d\n", $1, $2}' "$DDIR/$d/${d}.el" > "$DDIR/$d/edge.csv"
	echo ID > "$DDIR/$d/vertex.csv"
	cat "$DDIR/$d/${d}.el" | tr '[:blank:]' '\n' | sort -n | uniq >> "$DDIR/$d/vertex.csv"

	# Convert to GraphMat format
	# GraphMat requires edge weights---Just make them all 1 for the .wel format
	# XXX: What happens when you remove selfloops and duplicated edges.
	awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$DDIR/$d/${d}.el" > "$DDIR/$d/$d.1el"
	awk '{printf "%d\n", ($1+1)}' "$DDIR/$d/${d}-roots.v" > "$DDIR/$d/${d}-roots.1v"
	# nvertices is a bit of a misnomer; it should actually be "max vertex id"
	nvertices=$(( $(sort -n "$DDIR/$d/vertex.csv" | tail -n 1) + 1 ))
	"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 0 --outputedgeweights 2 --nvertices $nvertices "$DDIR/$d/$d.1el" "$DDIR/$d/$d.graphmat"

	# Convert to Galois format.
	# Currently, their unweighted graph format (vgr) doesn't work so we add 1s as weights.
	# "$GALOISDIR/tools/graph-convert/graph-convert" -edgelist2vgr "$DDIR/$d/$d.el" "$DDIR/$d/$d.vgr"
	awk '{print $1 " " $2 " " 1}' "$DDIR/$d/$d.el" > "$DDIR/$d/$d.wel"
	"$GALOISDIR/tools/graph-convert/graph-convert" -intedgelist2gr "$DDIR/$d/$d.wel" "$DDIR/$d/$d.gr"
fi
cd "$OLDPWD"

# TEST: Convert back to non-binary, see what we get
# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 1 --inputformat 0 --outputformat 1 --inputheader 1 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 "$DDIR/$d.graphmat" "$DDIR/$d.test.wel"

