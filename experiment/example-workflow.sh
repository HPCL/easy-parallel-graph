#!/bin/bash
# An example workflow, going from building the libraries to
# generating some figures.
# Synthetic datasets are stored in output/kron-$S
mkdir -p output
THREADS="1 2 4 8 16 24 32 40 48 56"
S=12
NUM_ROOTS=16
./get-libraries.sh
./gen-datasets.sh $S
for T in $THREADS; do
	./run-experiment.sh --num-roots=$NUM_ROOTS $S $T
done
./parse-output.sh $S

THREAD_ARR=($THREADS)
echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- c(${THREADS// /,})
focus_thread <- ${THREAD_ARR[-2]} # Pick the second to last thread arbitrarily
focus_scale <- $S
" > example_config.R # Warning: this file is sourced in experiment_analysis.R
mkdir -p graphics
Rscript experiment_analysis.R example_config.R

DATASETS="dota-league cit-Patents"
for DSET in $DATASETS; do
	curl -o datasets/$DSET.zip https://atlarge.ewi.tudelft.nl/graphalytics/zip/$DSET.zip
	unzip -d datasets datasets/$DSET.zip
	mv datasets/$DSET/$DSET.e datasets/$DSET.e
	mv datasets/$DSET/$DSET.v datasets/$DSET.v
	./gen-datasets.sh -f=datasets/$DSET.e
	./run-experiment.sh -f=$DSET 32
	./parse-output.sh -f=$DSET
done

echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- 32
dataset_list <- c(${DATASETS// /,})
" > ${DSET}_config.R # Warning: this file is sourced in experiment_analysis.R
Rscript realworld_analysis.R ${DSET}_config.R

