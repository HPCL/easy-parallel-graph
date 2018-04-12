#!/bin/bash
#exmple: ./run-workflow.sh email-Enron datasets.txt
set -e
echo "usage: $0 <dset> <dset_config> <threads>"
DSET="$1"
DSET_CONFIG="$2"
working_dir=`pwd`
DATASET_FILE="../experiment/datasets/${DSET}/${DSET}.txt"
no_of_threads="$3"
cd ../experiment/datasets
mkdir -p ${DSET}

cd ../../cleaned

# TODO: Get the third line in dset_config and download it
# wget https://snap.stanford.edu/data/email-Enron.txt.gz

i=0
while read p; do
 let "i+=1"
 if [ $((i%3)) -eq 0 ]
 then
  wget $p
  mv ${p##*/} ../experiment/datasets/$DSET/${p##*/}

 fi
done <$2


./unzipper.sh $DSET_CONFIG
echo done unzipping..
python vertex_convert.py $DATASET_FILE
echo done converting..
mv new_graph.txt ../experiment/datasets/$DSET/${DSET}.txt
echo done moving..
cd ../experiment
./gen-datasets.sh -f=datasets/$DSET/${DSET}.txt
./run-realworld.sh datasets/$DSET/${DSET}.txt ${no_of_threads}
./parse-output.sh -f=${DSET}
