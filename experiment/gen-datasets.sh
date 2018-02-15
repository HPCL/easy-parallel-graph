#!/bin/bash
USAGE="usage: gen-datasets.sh [--libdir=<dir>] [--ddir=<dir>] [--rmat=<params>] -f=<filename>|<scale>
	You may either provide a file path (e.g. gen-datasets.sh -f=datasets/file.wel) or an
	integer (e.g. gen-datasets.sh 20) to generate an RMAT graph with 2^<scale> vertices.
	The current filetypes supported are of the form
		<edge1> <edge2> with optional comment lines beginning with # or %
	OR
		<edge1> <edge2> <weight> with optional comment lines beginning with # or %
	--libdir: repositories directory. Default: ./lib
	--ddir: dataset directory. Default: ./datasets
	--rmat: Use <params> for the RMAT parameters. These are space-separated, so you'll
		have to quote them. You can provide 3 or 4. For example, --rmat='0.5 0.2 0.2'.
		Default: '0.57 0.19 0.19 0.05'. If the default, graph files are
		stored in kron-<scale>, otherwise kron-<scale>_<a>_<b>_<c>_<d>
		only use if with <scale> (not -f)"
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
#     pre/
#         pre.v
#         pre.e
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
RMAT_PARAMS="0.57 0.19 0.19 0.05"
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
		# Handle KONECT style where the file looks like out.actor-collaboration
		if [ "$FILE_PREFIX" = 'out' ]; then
			FILE_PREFIX=$(basename $FILE)
			FILE_PREFIX=${FILE_PREFIX#out.}
		fi
		shift
	;;
	--rmat=*)
		RMAT_PARAMS=${arg#*=}
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
	[1-9]|[0-9][0-9]*) # scale between 1--99 is robust enough
		S=$1
		FILE_PREFIX="kron-$S"
	;;
	*) # Default
		echo "<scale> must be between 1--99"
		exit 2
	;;
	esac
fi
echo "Starting data set generation at $(date)"

mkdir -p "$DDIR"
NRT=64
GAPDIR="$LIBDIR/gapbs"
GRAPH500DIR="$LIBDIR/graph500"
GRAPHMATDIR="$LIBDIR/GraphMat"
GALOISDIR="$LIBDIR/Galois-2.2.1/build/default"
SNAPDIR="$LIBDIR/snap/examples/feature_csv"

###
# Real world datasets as provided by Graphalytics, SNAP, or KONECT
###
if [ "$FILE_PREFIX" != "kron-$S" ]; then
	d="$FILE_PREFIX" # For convenience
	mkdir -p "$DDIR/$d"
	echo Converting $FILE into the correct formats, basename $d...
	# If it's from SNAP then there may be some comments
	if [ ! -f "$DDIR/$d/$d.e" ]; then
		if [ ! -f "$FILE" ]; then
			echo "Cannot find file $FILE (cwd is $(pwd))"
			exit 1
		fi
		# Delete carriage returns and comments
		# SNAP comment is #, KONECT comment is %
		tr -d $'\r' < "$FILE" > "$FILE.bak"
		mv "$FILE.bak" "$FILE"
		awk '!/^#/ && !/^%/{print}' "$FILE" > "$DDIR/$d/$d.e"
	fi
	OLDPWD=$(pwd)
	cd "$DDIR/$d"
	if [ ! -f "$d.v" ] || [ "$(wc -l < $d.v)" -eq 0 ]; then
		echo "Creating $d.v..."
		cat  "$d.e" | tr '[:blank:]' '\n'| sort -n | uniq > $d.v
	fi
	# nvertices is a bit of a misnomer; it should actually be "max vertex id"
	nvertices=$(( $(sort -n "$d.v" | tail -n 1) + 1))
	echo -n  "Checking whether $d.e is weighted or unweighted..."
	if [ $(awk '{print NF; exit}' "$d.e") -eq 2 ]; then
		echo " unweighted."
		echo "SRC,DEST" > "edge.csv"
		# Add 1 to ensure it's at least 1-indexed. It won't hurt.
		awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$d.e" > "$d.el"
		# Get the roots by running SSSP and making sure you can visit a good
		# number of vertices GAP output is e.g. "took 382 iterations".
		# We don't want it to take 1 iteration.
		echo "Getting roots."
		"$GAPDIR/sssp" -f "$d.el" -n $(($NRT*2)) > tmp.log
		# We write a serialized graph to speed up GAP
		"$GAPDIR/converter" -s -f "$d.el" -b "$d.sg"

		echo Writing the graph transpose to "${d}-t.el"
		awk '{print $2 " " $1}' "$d.el" > "${d}-t.el"

		# GraphMat doesn't write out an unweighted graph. So we have output unit edge weights.
		"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 0 --outputedgeweights 2 --nvertices $nvertices "$d.el" "$d.graphmat"
		# Convert to Galois format
		echo "Converting to Galois format. Adding unit weights"
		awk '{print $1 " " $2 " " 1}' "$d.el" > "$d.wel"
		"$GALOISDIR/tools/graph-convert/graph-convert" -intedgelist2gr "$DDIR/$d/$d.wel" "$DDIR/$d/$d.gr"
		echo Writing the graph transpose to "$DDIR/$d/${d}-t.gr"
		"$GALOISDIR/tools/graph-convert/graph-convert" -gr2tintgr "$DDIR/$d/$d.gr" "$DDIR/$d/${d}-t.gr"

	elif [ $(awk '{print NF; exit}' "$d.e") -eq 3 ]; then
		echo " weighted."
		echo "SRC,DEST,WEIGHT" > "edge.csv"
		awk '{printf "%d %d %s\n", ($1+1), ($2+1), $3}' "$d.e" > "$d.wel"
		awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$d.e" > "$d.el" # For GraphMat

		echo "Getting roots."
		"$GAPDIR/sssp" -f "$d.el" -n $(( $NRT * 2 )) > tmp.log
		# TODO: Use this in real-datasets, change WeightT to float if need be and recompile GAPBS
		"$GAPDIR/converter" -s -f "$d.wel" -wb "$d.wsg"
		# We make no assumptions so we output double precision edge weights
		# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 1 --outputedgeweights 0 --edgeweighttype 1 --nvertices $nvertices "$d/$d.wel" "$d/$d.graphmat"
		"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 0 --outputedgeweights 2 --nvertices $nvertices "$d.el" "$d.graphmat"
		# Convert to Galois format
		"$GALOISDIR/tools/graph-convert/graph-convert" -doubleedgelist2gr "$DDIR/$d/$d.wel" "$DDIR/$d/$d.gr"
	else
		echo "File format not recognized"
		cd "$OLDPWD"
		exit 1
	fi
	awk -v NRT=$NRT '/Source/{src=$2}/took [0-9]+ iterations/{if($2>1 && cnt<NRT){printf "%d\n", src; cnt++}}' tmp.log > "$DDIR/$d/$d-roots.v"
	awk '{printf "%d\n", ($1+1)}' "$DDIR/$d/${d}-roots.v" > "$DDIR/$d/${d}-roots.1v"
	rm tmp.log
	sed 's/[:space:]+/,/' "$DDIR/$d/$d.e" >> "$DDIR/$d/edge.csv"
	echo "ID" > "$DDIR/$d/vertex.csv"
	sed 's/[:space:]+/,/' "$DDIR/$d/$d.v" >> "$DDIR/$d/vertex.csv"
	# Generate features
	if ! [ -f "$DDIR/$d/features.csv" ]; then
		$SNAPDIR/feature_csv "$DDIR/$d/$d.el" > "$DDIR/$d/features.csv"
	fi
###
# Synthetic datasets to the Graph500 specification
###
else
	# Generate graph (Graph500 can only save to its binary format)
	if ! [ "$RMAT_PARAMS" = "0.57 0.19 0.19 0.05" ]; then
		d="${FILE_PREFIX}_$(echo $RMAT_PARAMS | tr ' ' '_')"
	else
		d="$FILE_PREFIX"
	fi
	mkdir -p "$DDIR/$d"
	# Various ways to generate RMAT
	../RMAT/driverForRmat $S -1 16 $RMAT_PARAMS "$DDIR/$d/$d.el"
	#"$GRAPH500DIR/graph5002el" "$DDIR/$d/$d.graph500" "$DDIR/$d/$d.roots" "$DDIR/$d/$d.el" "$DDIR/$d/${d}-roots.v" # TODO
	#"$GAPDIR/converter" -g $S -e "$DDIR/$d/$d.el"

	# Symmetrize (make undirected)
	# Making the graph undirected results in identical output for all but TC.
	# TODO: Investigate if the same holds for TC. If you want it directed, use below instead:
	#EL_FILE="$DDIR/$d/${d}.el"
	EL_FILE="$DDIR/$d/${d}-undir.el"
	"$GAPDIR/converter" -g $S -s -e "$EL_FILE"

	# Convert to GAP serialized format
	"$GAPDIR/converter" -g $S -s -b "$DDIR/$d/$d.sg"

	# Generate roots (usually graph500 does this but it doesn't work for scale > 22)
	"$GAPDIR/bfs" -n $NRT -f "$DDIR/$d/$d.sg" | awk '/Source/{print $2}' > "$DDIR/$d/${d}-roots.v"

	# Sort the roots (mitigate that weird issue with GraphBIG not working for root > # vertices read)
	cat "$DDIR/$d/${d}-roots.v" | sort -n > tmp.txt
	cp tmp.txt "$DDIR/$d/${d}-roots.v"
	rm tmp.txt
	awk '{printf "%d\n", ($1+1)}' "$DDIR/$d/${d}-roots.v" > "$DDIR/$d/${d}-roots.1v"

	# Convert to GraphBIG format
	awk 'BEGIN{print "SRC,DEST"} {printf "%d,%d\n", $1, $2}' "$EL_FILE" > "$DDIR/$d/edge.csv"
	echo ID > "$DDIR/$d/vertex.csv"
	cat "$EL_FILE" | tr '[:blank:]' '\n' | sort -n | uniq >> "$DDIR/$d/vertex.csv"

	# Convert to GraphMat format
	# GraphMat requires edge weights---Just make them all 1 for the .wel format
	# TODO: What happens when you remove selfloops and duplicated edges.
	awk '{printf "%d %d\n", ($1+1), ($2+1)}' "$EL_FILE" > "$DDIR/$d/$d.1el"
	awk '{printf "%d\n", ($1+1)}' "$DDIR/$d/${d}-roots.v" > "$DDIR/$d/${d}-roots.1v"
	# nvertices is a bit of a misnomer; it should actually be "max vertex id"
	nvertices=$(( $(sort -n "$DDIR/$d/vertex.csv" | tail -n 1) + 1 ))
	"$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 0 --bidirectional --inputformat 1 --outputformat 0 --inputheader 0 --outputheader 1 --inputedgeweights 0 --outputedgeweights 2 --nvertices $nvertices "$EL_FILE" "$DDIR/$d/$d.graphmat"

	# Convert to Galois format.
	# Currently, their unweighted graph format (vgr) doesn't work so we add 1s as weights.
	# "$GALOISDIR/tools/graph-convert/graph-convert" -edgelist2vgr "$DDIR/$d/$d.el" "$DDIR/$d/$d.vgr"
	awk '{print $1 " " $2 " " 1}' "$EL_FILE" > "$DDIR/$d/$d.wel"
	"$GALOISDIR/tools/graph-convert/graph-convert" -intedgelist2gr "$DDIR/$d/$d.wel" "$DDIR/$d/$d.gr"
	echo Writing the graph transpose to "$DDIR/$d/${d}-t.gr"
	"$GALOISDIR/tools/graph-convert/graph-convert" -gr2tintgr "$DDIR/$d/$d.gr" "$DDIR/$d/${d}-t.gr"
	# Generate features
	$SNAPDIR/feature_csv "$DDIR/$d/$d.el" > "$DDIR/$d/features.csv"
fi
cd "$OLDPWD"
echo "Completed data set generation at $(date)"

# TEST: Convert back to non-binary, see what we get
# "$GRAPHMATDIR/bin/graph_converter" --selfloops 1 --duplicatededges 1 --inputformat 0 --outputformat 1 --inputheader 1 --outputheader 1 --inputedgeweights 1 --outputedgeweights 2 "$DDIR/$d.graphmat" "$DDIR/$d.test.wel"

