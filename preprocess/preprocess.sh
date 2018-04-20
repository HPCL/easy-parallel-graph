#!/bin/bash
#exmple: ./run-workflow.sh email-Enron datasets.txt
set -e
echo "usage: $0 <dataset config txt file>"
DSET_CONFIG="$1"

i=0
while read p; do
	let "i+=1"
	if [ $((i%3)) -eq 1 ] && [ "${p:0:1}" != '#' ]; then
		DSET=$p
		mkdir -p ../experiment/datasets/${DSET}
	elif [ $((i%3)) -eq 2 ] && [ "${p:0:1}" != '#' ]; then
		: # Unused for now
	elif [ $((i%3)) -eq 0 ] && [ "${p:0:1}" != '#' ]; then
		wget -nc $p -P ../experiment/datasets/$DSET
	fi
done < $DSET_CONFIG

./unzipper.sh $DSET_CONFIG
echo done unzipping..

i=0
while read p; do
	let "i+=1"
	if [ $((i%3)) -eq 1 ] && [ "${p:0:1}" != '#' ]; then
		DSET=$p
		echo "Processing $DSET.."
		# SNAP
		if [ -f "../experiment/datasets/${DSET}/${DSET}.txt" ]; then
			DATASET_FILE="../experiment/datasets/${DSET}/${DSET}.txt" 
			COMMENT='#'
		# KONET
		elif [ -f "../experiment/datasets/${DSET}/out.${DSET}" ]; then
			DATASET_FILE="../experiment/datasets/${DSET}/out.${DSET}"
			COMMENT='%'
		else
			echo "Unable to find graph file for $DSET. It probably has a weird filename"
			continue
		fi
		VID=$(head -n 50 $DATASET_FILE | awk 'BEGIN{m=2^31} !/^#/ && !/^%/{if ($1<m) m=$1} END{print m}')
		if [ "$VID" -gt 1000000 ]; then
			echo "Remapping vertex ids"
			python vertex_convert.py $DATASET_FILE $COMMENT
			mv new_graph.txt $DATASET_FILE
		fi
		echo "Generating dataset"
		cd ../experiment
		./gen-datasets.sh -f=datasets/$DSET/$(basename $DATASET_FILE)
		cd -
	fi
done < $DSET_CONFIG

