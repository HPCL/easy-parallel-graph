# Simple example to run a single dataset with a few different thread numbers

# Synthetic dataset
S=13
THREADS="1 2 4"
./get-libraries.sh
./gen-datasets.sh $S
for T in $THREADS; do
	./run-experiment.sh $S $T
done
./parse-output.sh $S

# A realworld dataset
DSET=dota-league
curl -o datasets/$DSET.zip https://atlarge.ewi.tudelft.nl/graphalytics/zip/$DSET.zip
mkdir -p datasets/$DSET
unzip -d datasets/$DSET datasets/$DSET.zip
./gen-datasets.sh -f=datasets/$DSET/$DSET.e
# Once you've generated the dataset you can use either the dataset prefix
# or the full filename
for T in $THREADS; do
	./run-realworld.sh datasets/$DSET/$DSET $T
done
./parse-output.sh datasets/$DSET/$DSET

# Synthetic Analysis
echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- c(${THREADS// /,})
focus_thread <- 2 # Pick this arbitrarily
focus_scale <- $S
" > example_config.R # Warning: this file is sourced in experiment_analysis.R
mkdir -p graphics
Rscript experiment_analysis.R example_config.R

# Realworld analysis
echo "# Config file for realworld_analysis.R
prefix <- './output/'
threads <- c(${THREADS// /,})
dataset_list <- c('dota-leauge')
" > example_realworld_config.R  # Warning: this file is sourced in realworld_config.R
Rscript realworld_analysis.R example_realworld_config.R

