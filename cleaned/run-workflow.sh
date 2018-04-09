#!/bin/bash
# example: ./run-workflow.sh email-Enron datasets.txt
set -e
echo "usage: $0 <dset> <dset_config> <threads>"
DSET="$1"
DSET_CONFIG="$2"
working_dir=`pwd`
DATASET_FILE="${DSET}.txt"
no_of_threads="$3"

# TODO: Get the third line in dset_config and download it
# wget https://snap.stanford.edu/data/email-Enron.txt.gz
./unzipper.sh $DSET_CONFIG
python vertex_convert.py $DATASET_FILE
mv new_graph.txt ../experiment/datasets/$DSET/${DSET}.txt
cd ../experiment
./gen-datasets.sh -f=datasets/$DSET/${DSET}.txt
./run-realworld.sh datasets/$DSET/${DSET}.txt ${no_of_threads}
./parse-output.sh -f=${DSET}

