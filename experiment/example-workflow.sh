#!/bin/bash
# An example workflow, going from building the libraries to
# generating some figures.
# Synthetic datasets are stored in output/kron-$S
mkdir -p output
THREADS="1 2 4 8 16 32 64 72"
S=22
./get-libraries.sh
./gen-datasets.sh $S
for T in $THREADS; do
	./run-experiment.sh $S $T
done
./parse-output.sh $S
echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- c(${THREADS// /,})
scale <- $S
" > example_config.R # Warning: this file is sourced in experiment_analysis.R
mkdir -p graphics
Rscript experiment_analysis.R example_config.R

# Dota-league dataset
DSET=dota-league
curl -o datasets/$DSET.zip https://atlarge.ewi.tudelft.nl/graphalytics/zip/$DSET.zip
unzip -d datasets datasets/$DSET.zip
mv datasets/$DSET/$DSET.e datasets/$DSET.e
mv datasets/$DSET/$DSET.v datasets/$DSET.v
./gen-datasets.sh -f=datasets/$DSET.e
./run-experiment.sh -f=$DSET 32
./parse-output.sh -f=$DSET

echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- 32
dataset <- '$DSET'
" > ${DSET}_config.R # Warning: this file is sourced in experiment_analysis.R
Rscript realworld_analysis.R ${DSET}_config.R

