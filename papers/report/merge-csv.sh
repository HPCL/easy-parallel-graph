#!/bin/bash
# Merges two csv files, given that they both only use one dataset for each run.
# To use with latex: ./merge-csv.sh > runtimes.csv
# Grabs all of the runs for a given dataset and averages them.
# To specify: The EXPERIMENT_DIR directory specicies where the output is saved.  
EXPERIMENT_DIR=/home/users/spollard/graphalytics/experiments
PLATFORMS="openg powergraph graphmat"

first=1
outfile=runtime.csv
N_EXPERIMENTS=0
if [ -z "$EXPERIMENT_DIR" ]; then
	echo "Please specify where the output csv files are located."
	exit 1
fi
# Compute the mean runtime for each platform and store the results in the cwd
for p in $PLATFORMS; do
	P_RUNS=$(find "$EXPERIMENT_DIR" -path */"${p}"-report-*/runtime.csv)
	awk -F ',' '/^,/{if (ARGIND==1) print $0} !/^,/{A[$1] += $2} END{for (alg in A) print alg "," (A[alg] / ARGIND)}' $P_RUNS > "${p}-runtime.csv"
	N_EXPERIMENTS=$(awk 'BEGIN{print ARGC - 1}' $P_RUNS)
	echo "$p has $N_EXPERIMENTS experiment(s)"
done
# Assumes there is only one dataset---named $dataset1.
echo "Writing"
for f in *-runtime.csv; do
	if [ "$first" -eq 1 ]; then
 		first=0
 		experiment1=${f%-runtime.csv}
 		dataset1=$(grep '^,' $f | cut -b 2-)
 		cat "$f" | sed "s/$dataset1/$experiment1/" > $outfile
 	else
 		experimentn=${f%-runtime.csv}
		cat "$f" | cut -d ',' -f 2- | sed "s/$dataset1/$experimentn/" | paste -d, runtime.csv	- | tee "$outfile"
 	fi
done
echo "to $outfile using dataset $dataset1"

