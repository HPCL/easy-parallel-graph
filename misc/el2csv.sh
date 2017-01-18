#!/bin/bash
# Convert a graph in edge list format (.el) to one
# compatible with GraphBIG. This will look like
# mydata.el
# mydata/
#   vertex.csv
#   edge.csv

USAGE="el2csv.sh </full/path/to/dataset file>"
if [ -z $1 ]; then
	echo $USAGE
	exit 2
fi
BASE_DIR=$(dirname $1)
if [ -z $BASE_DIR ]; then
	echo $USAGE
	exit 2
fi
# For example, /home/spollard/data/myfile.el -> myfile
BASE_FN=$(basename $1)
BASE_FN=${BASE_FN%.*}
mkdir -p "$BASE_DIR/$BASE_FN"
awk 'BEGIN{print "SRC,DEST"} {printf "%d,%d\n", $1, $2}' $1 > "$BASE_DIR/$BASE_FN/edge.csv"
echo ID > "$BASE_DIR/$BASE_FN/vertex.csv"
cat $1 | tr ' ' '\n' | uniq >> "$BASE_DIR/$BASE_FN/vertex.csv"

