#!/bin/bash
# An example workflow, going from building the libraries to
# generating some figures.
# NOTE: This is in the early stages of development so currently
# the experiments will just append to existing log files.
# IF YOU STOP AN EXPERIMENT HALFWAY DELETE THE LOG FILES
# they are stored in output/kron-$S
THREADS="1 2 4 8 16"
S=13
./get-libraries.sh
./gen-datasets.sh $S
for T in $THREADS; do
	./run-experiment.sh $S $T
done
./parse-output.sh $S
echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
threads <- c(${THREADS// /,})
scale <- $S
" > example_config.R # Warning: this file is sourced in experiment_analysis.R
mkdir -p graphics
Rscript experiment_analysis.R example_config.R

