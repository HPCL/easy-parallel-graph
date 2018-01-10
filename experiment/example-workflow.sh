#!/bin/bash
# An example workflow, going from building the libraries to
# generating some figures.
# Synthetic datasets are stored in output/kron-$S

# Talapas partitions: short, long, gpu, longgpu, fat, longfat, preempt, jhp, steck
mkdir -p run_logs
mkdir -p output
THREADS="1 2 4 8 16 24 32 40 48 56"
S=21
NUM_ROOTS=16

DRYRUN=True # Echo commands instead of run them
SLURM=True
# Job scheduler commands
JS_TIME=20:00:00
JS_CPUS=28
JS_PARTITION=short

if [ "$DRYRUN" = 'True' ]; then
	ANALYZE='echo '
else
	ANALYZE='' # We assume you want to run analysis interactively. It doesn't take long.
fi

# usage: run [-serror error_file] [-soutput output_file] [-sjob job_name] executable [args]...
run()
{
	local cmd
	if [ $SLURM = 'True' ]; then
		cmd="sbatch -t $JS_TIME --cpus-per-task=$JS_CPUS --partition=$JS_PARTITION"
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
for T in $THREADS; do
	run -serror run_logs/${S}-${T}t.err -soutput run_logs/${S}-${T}t.out -sjob epg${T}t-$S ./run-experiment.sh --num-roots=$NUM_ROOTS $S $T
done

# Graphalytics datasets
GA_DATASETS="dota-league cit-Patents"
for DSET in $GA_DATASETS; do
	${ANALYZE}curl -o datasets/$DSET.zip https://atlarge.ewi.tudelft.nl/graphalytics/zip/$DSET.zip
	${ANALYZE}mkdir -p datasets/$DSET
	${ANALYZE}unzip -d datasets/$DSET datasets/$DSET.zip
	run -serror run_logs/gen${DSET}.err -soutput run_logs/gen${DSET}.out -sjob epg-gen${S} ./gen-datasets.sh -f=datasets/$DSET/$DSET.e
	for T in $THREADS; do
		run -serror run_logs/$DSET-${T}t.err -soutput run_logs/${DSET}-${T}t.out -sjob epg${T}t-${DSET} ./run-experiment.sh --num-roots=$NUM_ROOTS datasets/$DSET/$DSET $T
	done
done

# Snap or KONECT datasets
${ANALYZE}../learn/unzipper.sh ../learn/datasets.txt datasets
S_K_DATASETS=$(awk -v ORS=' ' 'FNR%3 == 1 {print}' ../learn/datasets.txt )
for DSET in $S_K_DATASETS; do
	if [ -f "datasets/$DSET/out.$DSET" ]; then # KONECT
		run -serror run_logs/gen${DSET}.err -soutput run_logs/gen${DSET}.out -sjob epg-gen-${DSET} ./gen-datasets.sh -f=datasets/$DSET/out.${DSET}
	else # SNAP
		run -serror run_logs/gen${DSET}.err -soutput run_logs/gen${DSET}.out -sjob epg-gen-${DSET} ./gen-datasets.sh -f=datasets/$DSET/${DSET}.txt
	fi
	for T in $THREADS; do
		run -serror run_logs/$DSET-${T}t.err -soutput run_logs/$DSET-${T}t.out -sjob epg${T}t-${DSET} ./real-datasets.sh --num-roots=$NUM_ROOTS datasets/$DSET/$DSET $T
	done
done

# Analyze synthetic datasets
${ANALYZE}./parse-output.sh $S
THREAD_ARR=($THREADS)
echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- c(${THREADS// /,})
focus_thread <- ${THREAD_ARR[-2]} # Pick the second to last thread arbitrarily
focus_scale <- $S
" > example_config.R # Warning: this file is sourced in experiment_analysis.R
mkdir -p graphics
${ANALYZE}Rscript experiment_analysis.R example_config.R

# Analyze realworld datasets
DATASETS="$GA_DATASETS $S_K_DATASETS"
for DSET in $DATASETS; do
	${ANALYZE}./parse-output.sh -f=$DSET
done
for DSET in $S_K_DATASETS; do
	${ANALYZE}./parse-output.sh -f=$DSET
done
echo "# Config file for experiment_analysis.R. threads a vector, scale an int.
prefix <- './output/'
threads <- ${THREAD_ARR[-2]} # Pick the second to last thread arbitrarily
dataset_list <- c(${DATASETS// /,})
" > realworld_config.R # Warning: this file is sourced in experiment_analysis.R
${ANALYZE}Rscript realworld_analysis.R ${DSET}_config.R

