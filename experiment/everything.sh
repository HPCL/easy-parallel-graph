#!/bin/bash
# This runs everything that epg* is capable of.
# By default, it is a DRYRUN that just prints everything so you can run
# at your own leisure
# This goes from building the libraries to generating some figures.
# If you want to see something simpler, try example.sh

# Talapas partitions: short, long, gpu, longgpu, fat, longfat, preempt, jhp, steck
mkdir -p run_logs
mkdir -p output
THREADS="1 2 4 8 16 24 32 40 48 56"
S=21
NUM_ROOTS=16

DRYRUN=True # Echo commands instead of run them
SLURM=True
COPY='--copy-to=/tmp' # Leave blank for no copying of datasetes
# Job scheduler commands
JS_TIME=20:00:00
JS_CPUS=28
JS_PARTITION=short
JS_MEMORY=128G

if [ "$DRYRUN" = 'True' ]; then
	ANALYZE='echo '
else
	ANALYZE='' # We assume you can run analysis, installation, etc. interactively. It doesn't take long.
fi

# usage: run [-serror error_file] [-soutput output_file] [-sjob job_name] executable [args]...
run()
{
	local cmd
	if [ $SLURM = 'True' ]; then
		cmd="sbatch -t $JS_TIME --cpus-per-task=$JS_CPUS --partition=$JS_PARTITION --mem=$JS_MEMORY"
	fi
	if [ "$DRYRUN" = 'True' ]; then
		cmd="echo $cmd"
	fi
	for arg in "$@"; do
		case $arg in
		-serror)
			shift
			cmd="$cmd -e $1"
			shift
		;;
		-soutput)
			shift
			cmd="$cmd -o $1"
			shift
		;;
		-sjob)
			shift
			cmd="$cmd -J $1"
			shift
		;;
		esac
	done
	$cmd $@
}

${ANALYZE}./get-libraries.sh
run -serror run_logs/gen${S}.err -soutput run_logs/gen${S}.out ./gen-datasets.sh $S

# Synthetic datasets
echo -e '\n# Running Synthetic datasets'
for T in $THREADS; do
	run -serror run_logs/${S}-${T}t.err -soutput run_logs/${S}-${T}t.out -sjob epg${T}t-$S ./run-synthetic.sh --num-roots=$NUM_ROOTS $COPY $S $T
done

# Generating Graphalytics datasets
echo -e '\n# Generating Graphalytics datasets'
GA_DATASETS="dota-league cit-Patents kgs com-friendster twitter_mpi wiki-Talk"
for DSET in $GA_DATASETS; do
	${ANALYZE}curl -o datasets/$DSET.zip https://atlarge.ewi.tudelft.nl/graphalytics/zip/$DSET.zip
	${ANALYZE}mkdir -p datasets
	${ANALYZE}unzip -d datasets datasets/$DSET.zip
	run -serror run_logs/gen${DSET}.err -soutput run_logs/gen${DSET}.out -sjob epg-gen-${DSET} ./gen-datasets.sh -f=datasets/$DSET/$DSET.e
done
# Generating SNAP and KONECT datasets'
echo -e '\n# Generating SNAP and KONECT datasets'
${ANALYZE}../learn/unzipper.sh ../learn/datasets.txt datasets
S_K_DATASETS=$(awk -v ORS=' ' 'FNR%3 == 1 && !/^#/ {print}' ../learn/datasets.txt )
for DSET in $S_K_DATASETS; do
	if [ -f "datasets/$DSET/out.$DSET" ]; then # KONECT
		run -serror run_logs/gen${DSET}.err -soutput run_logs/gen${DSET}.out -sjob epg-gen-${DSET} ./gen-datasets.sh -f=datasets/$DSET/out.${DSET}
	else # SNAP
		run -serror run_logs/gen${DSET}.err -soutput run_logs/gen${DSET}.out -sjob epg-gen-${DSET} ./gen-datasets.sh -f=datasets/$DSET/${DSET}.txt
	fi
done

# Run Graphalytics datasets
echo -e '\n# Running Graphalytics datasets'
for DSET in $GA_DATASETS; do
	for T in $THREADS; do
		run -serror run_logs/$DSET-${T}t.err -soutput run_logs/${DSET}-${T}t.out -sjob epg${T}t-${DSET} ./run-realworld.sh --num-roots=$NUM_ROOTS datasets/$DSET/$DSET $T
	done
done
# Run SNAP and KONECT datasets
echo -e '\n# Running SNAP and KONECT datasets\n'
for DSET in $S_K_DATASETS; do
	for T in $THREADS; do
		run -serror run_logs/$DSET-${T}t.err -soutput run_logs/$DSET-${T}t.out -sjob epg${T}t-${DSET} ./run-realworld.sh --num-roots=$NUM_ROOTS $COPY datasets/$DSET/$DSET $T
	done
done

# Analyze synthetic datasets
echo -e '\n# Analyzing synthetic datasets'
${ANALYZE}./parse-output.sh $S
THREAD_ARR=($THREADS)
echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- c(${THREADS// /,})
focus_thread <- ${THREAD_ARR[-2]} # Pick the second to last thread arbitrarily
focus_scale <- $S
" > all_config.R # Warning: this file is sourced in experiment_analysis.R
mkdir -p graphics
${ANALYZE}Rscript experiment_analysis.R all_config.R

# Analyze realworld datasets
echo -e '\n# Analyzing realworld datasets'
DATASETS="$GA_DATASETS $S_K_DATASETS"
for DSET in $DATASETS; do
	${ANALYZE}./parse-output.sh -f=$DSET
done
echo "# Config file for realworld_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- ${THREAD_ARR[-2]} # Pick the second to last thread arbitrarily
dataset_list <- c(${DATASETS// /,})
" > realworld_config.R # Warning: this file is sourced in realworld_config.R
${ANALYZE}Rscript realworld_analysis.R ${DSET}_config.R

