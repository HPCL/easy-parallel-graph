#!/bin/bash
# A script to download all the datasets.
# This probably never needs to be done, but it keeps everything straight.
# usage:  get-datasets.sh [--download] <output-dir>
usage='usage: get-datasets.sh [--dir=<output-dir>]

	Running the script with no arguments will simply print out all the URLs
	for each dataset along with their formats.'

DOWNLOAD_DIR=""
if [ $# -ge 1 ]; then
	case $1 in
		--dir=*)
		DOWNLOAD_DIR=${1#*=}
		if [ -z "$DOWNLOAD_DIR" ]; then
			echo "If you want to download the files specify a directory."
			echo -e "$usage"
			exit 2
		fi
		;;
		-h|--help)
			echo "$usage"
			exit 0
		;;
		*)
			echo "Unrecognized option."
			echo "$usage"
		;;
	esac
fi

if [ ! -z "$DOWNLOAD_DIR" ]; then
	echo "Downloading to $DOWNLOAD_DIR"
fi

echo GraphBIG data cannot be download noninteractively. Please go to
echo https://github.com/graphbig/graphBIG/wiki/GraphBIG-Dataset

# DIMACS Grand Challenge #10
# David A. Bader, Andrea Kappes, Henning Meyerhenke, Peter Sanders, Christian Schulz and Dorothea Wagner. Benchmarking for Graph Clustering and Partitioning. In Encyclopedia of Social Network Analysis and Mining, pages 73-82. Springer, 2014.
# 
# David A. Bader, Henning Meyerhenke, Peter Sanders, Dorothea Wagner (eds.): Graph Partitioning and Graph Clustering. 10th DIMACS Implementation Challenge Workshop. February 13-14, 2012. Georgia Institute of Technology, Atlanta, GA. Contemporary Mathematics 588. American Mathematical Society and Center for Discrete Mathematics and Theoretical Computer Science, 2013.
if [ ! -z "$DOWNLOAD_DIR" ]; then
	OLDWD=$(pwd)
	cd "$DOWNLOAD_DIR"
	DELAUNAY_URL="http://www.cc.gatech.edu/dimacs10/archive/data/delaunay/delaunay_n10.graph.bz2"
	echo "Downloading a subset of the DIMACS Grand Challenge #10..." 
	echo Downloading $(basename "$DELAUNAY_URL")
	bunzip2 $(basename "$DELAUNAY_URL")
	wget --no-clobber "$DELAUNAY_URL"
fi
echo "Delaunay graphs---METIS Format. Source: http://www.cc.gatech.edu/dimacs10/archive/delaunay.shtml"

echo FORMATS:
echo DIMACS: http://dimacs.rutgers.edu/Challenges/
echo METIS: http://people.sc.fsu.edu/~jburkardt/data/metis_graph/metis_graph.html
echo MATRIX MARKET: http://math.nist.gov/MatrixMarket/formats.html
echo TRIVIAL GRAPH FORMAT "(TGF)" https://en.wikipedia.org/wiki/Trivial_Graph_Format
# Other types: Whatever graphalytics does (same as TGF but split into 2 files)
# pbbs: http://www.cs.cmu.edu/~pbbs/benchmarks/graphIO.html

cd "$OLDWD"
