#!/bin/bash
DSET="$1"
DSET_CONFIG="$2"
working_dir=`pwd`
DSET_DIR="${working_dir}/datasets/${DSET}/${DSET}.txt"
no_of_threads="$3"

./unzipper.sh $DSET_CONFIG
python vertex_convert.py $DSET_DIR
mv new_graph.txt fixed/${DSET}.txt
./gen-datasets.sh -f=fixed/${DSET}.txt
./run-realworld.sh fixed/${DSET}.txt ${no_of_threads}
./parse-output.sh -f=${DSET}





