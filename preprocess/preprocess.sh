#!/bin/bash
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
		: # Used in features.py
	elif [ $((i%3)) -eq 0 ] && [ "${p:0:1}" != '#' ]; then
		wget -nc $p -P ../experiment/datasets/$DSET
	fi
done < $DSET_CONFIG

python features.py # Try to parse features (will only work for SNAP)
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
			echo "Unable to find graph file for $DSET. Assuming it's gzipped SNAP format"
		fi
	fi
	if [ $((i%3)) -eq 0 ] && [ "${p:0:1}" != '#' ]; then	
		ZIP_FN="../experiment/datasets/${DSET}/$(basename $p)"
		if [ -f "$ZIP_FN" ]; then
			# XXX This will not work for anything other than .gz
			DATASET_FILE=${ZIP_FN%%.gz}
			# If in the first 50 lines you find a vertix > 1,000,000 then remap
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
		else
			echo Could not find file associated with $DSET
		fi
	fi
done < $DSET_CONFIG

