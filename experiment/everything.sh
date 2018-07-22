#!/bin/bash
# This runs everything that epg* is capable of.
# By default, it is a DRYRUN that just prints everything so you can run
# at your own leisure
# This goes from building the libraries to generating some figures.
# If you want to see something simpler, try example.sh

# Talapas partitions: short, long, gpu, longgpu, fat, longfat, preempt, jhp, steck
mkdir -p run_logs
mkdir -p output
THREADS="1 2 4 8 16 24 27 28 32 40 48 54 56"
S=22
NUM_ROOTS=10
REALWORLD_DATASET_FN=../preprocess/datasets2.txt

DRYRUN=True # Echo commands instead of run them
SLURM=True
COPY='--copy-to=/tmp' # Leave blank for no copying of datasetes
# Job scheduler commands
JS_TIME=16:00:00
JS_CPUS=28
JS_PARTITION=long
JS_MEMORY=128G # UNUSED

# Grid search parameters
GS=22

if [ "$DRYRUN" = 'True' ]; then
	ANALYZE='echo '
else
	ANALYZE='' # We assume you can run analysis, installation, etc. interactively. It doesn't take long.
fi

# usage: run [-serror error_file] [-soutput output_file] [-sjob job_name] [-S] executable [args]...
run()
{
	local cmd
	if [ $SLURM = 'True' ]; then
		# XXX: Memory seems to mess things up; just grab every core and you'll get all the memory
		#cmd="sbatch -t $JS_TIME --cpus-per-task=$JS_CPUS --partition=$JS_PARTITION --mem=$JS_MEMORY"
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
echo -e '\n# Running Synthetic datasets'
for T in $THREADS; do
	run -serror run_logs/${S}-${T}t.err -soutput run_logs/${S}-${T}t.out -sjob epg${T}t-$S ./run-synthetic.sh --num-roots=$NUM_ROOTS $COPY $S $T
done

# Grid search of rmat parameters. This is a lot of jobs.
# Steps:
# 1. Generate the RMAT
# 2. Run experiment, copying to /tmp for speed
# 3. Remove from tmp
# 4. Once all experiments have run, parse and move the parsed files
GRID=0.05
NUM_THREADS=0
for T in $THREADS; do NUM_THREADS=$(($NUM_THREADS + 1)); done
TIME_FORMULA_MIN="40 * 2^($GS-20) * $NUM_ROOTS + 26 * 2^($GS-20)"
TIMELIMIT=$(echo "1.1 * ($TIME_FORMULA_MIN) / 60 + 1" | bc):00:00
TIMELIMIT_GEN=$(echo " 45 * 2^($GS-20) / 60" | bc):00:00
echo "# RMAT grid search in increments of $GRID" > rmat_gridsearch_${GRID}.sh
echo "mkdir -p output/parsed_rmat_gridsearch_$GRID" >> rmat_gridsearch_${GRID}.sh
mkdir -p rmat_gridsearch_$GRID
for a in $(seq $GRID $GRID 0.99); do
	rem=$(echo "0.99 - $a" | bc)
	for b in $(seq 0.0 $GRID $rem); do
		rem=$(echo "$rem - $b - $GRID" | bc)
		for c in $(seq 0.0 $GRID $rem); do
			gf="rmat_gridsearch_$GRID/g_r${GS}_${a}_${b}_${c}.sh"
			# Unincluded
			#SBATCH --mem=$JS_MEMORY
			echo "#!/bin/bash
#SBATCH -e run_logs/g_${GS}_${a}_${b}_${c}.err
#SBATCH -o run_logs/g_${GS}_${a}_${b}_${c}.out
#SBATCH -J g_r${GS}_${a}_${b}_${c}
#SBATCH --cpus-per-task=$JS_CPUS
#SBATCH -t $TIMELIMIT_GEN
#SBATCH --partition=$JS_PARTITION

./gen-datasets.sh --rmat="\'"$a $b $c"\'" $GS
" > "$gf"
			for T in $THREADS; do
				rf="rmat_gridsearch_$GRID/r_t${T}_${GS}_${a}_${b}_${c}.sh"
			echo "#!/bin/bash
#SBATCH -e run_logs/r_t${T}_${GS}_${a}_${b}_${c}.err
#SBATCH -o run_logs/r_t{$T}_${GS}_${a}_${b}_${c}.out
#SBATCH -J g_r${GS}_${a}_${b}_${c}
#SBATCH --cpus-per-task=$JS_CPUS
#SBATCH -t $TIMELIMIT
#SBATCH --partition=$JS_PARTITION
" > "$rf"
				echo "./run-synthetic.sh --rmat="\'"$a $b $c"\'" --num-roots=$NUM_ROOTS $COPY $GS $T" >> "$rf"
				# echo "rm /tmp/$FILE_PREFIX/* && rmdir /tmp/$FILE_PREFIX" >> "$rf" # --copy-to handles this
			done
			FILE_PREFIX=kron-${GS}_${a}_${b}_${c}
			echo "sbatch rmat_gridsearch_$GRID/g_r${GS}_${a}_${b}_${c}.sh" >> rmat_gridsearch_${GRID}.sh
		done
	done
done

for a in $(seq $GRID $GRID 0.99); do
	rem=$(echo "0.99 - $a" | bc)
	for b in $(seq 0.0 $GRID $rem); do
		rem=$(echo "$rem - $b - $GRID" | bc)
		for c in $(seq 0.0 $GRID $rem); do
			for T in $THREADS; do
				echo "sbatch rmat_gridsearch_$GRID/r_t${T}_${GS}_${a}_${b}_${c}.sh" >> rmat_gridsearch_${GRID}.sh
			done
		done
	done
done
for a in $(seq $GRID $GRID 0.99); do
	rem=$(echo "0.99 - $a" | bc)
	for b in $(seq 0.0 $GRID $rem); do
		rem=$(echo "$rem - $b - $GRID" | bc)
		for c in $(seq 0.0 $GRID $rem); do
			for T in $THREADS; do
				echo "./parse-output.sh --rmat="\'"$a $b $c"\'" $GS" >> rmat_gridsearch_${GRID}.sh
				echo "mv output/parsed-kron-${GS}_${a}_${b}_${c}-*.csv output/parsed_rmat_gridsearch_$GRID" >> rmat_gridsearch_${GRID}.sh
			done
		done
	done
done

echo "# Once all the experiments have completed, run this" >> rmat_gridsearch_${GRID}.sh
echo "Rscript experiment_analysis.R rmat_gridsearch_${GRID}.R" >> rmat_gridsearch_${GRID}.sh


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
${ANALYZE}../preprocess/unzipper.sh $REALWORLD_DATASET_FN datasets
S_K_DATASETS=$(awk -v ORS=' ' 'FNR%3 == 1 && !/^#/ {print}' $REALWORLD_DATASET_FN )
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

