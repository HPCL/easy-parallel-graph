#!/bin/bash
# Merges two csv files, given that they both only use one dataset for each run.
# To use with latex: ./merge-csv.sh > runtimes.csv
# Grabs all of the runs for a given dataset and averages them.
# To specify: The EXPERIMENT_DIR directory specicies where the output is saved.  
EXPERIMENT_DIR=/home/users/spollard/graphalytics/experiments
first=1
outfile=runtime.csv
if [ -z "$EXPERIMENT_DIR" ]; then
	echo "Please specify where the output csv files are located."
	exit 1
fi
PLATFORMS="openg powergraph"
# Compute the mean runtime.
for p in $PLATFORMS; do
	P_RUNS=$(find "$EXPERIMENT_DIR" -path */"${p}"-report-*/"$outfile")
	awk -F ',' '/^,/{if (ARGIND==1) print $0} !/^,/{A[$1] += $2} END{for (alg in A) print alg "," (A[alg] / ARGIND)}' $P_RUNS > "${p}-runtime.csv"
done
# Assumes everything is in the same directory named "openg-runtime.csv" etc.
# Assumes there is only one dataset---named $dataset1.
for f in *-runtime.csv; do
	if [ "$first" -eq 1 ]; then
 		first=0
 		experiment1=${f%-runtime.csv}
 		dataset1=$(grep '^,' $f | cut -b 2-)
 		cat "$f" | sed "s/$dataset1/$experiment1/" > $outfile
 	else
 		experimentn=${f%-runtime.csv}
 		cat "$f" | cut -d ',' -f 2- | sed "s/$dataset1/$experimentn/" | lam runtime.csv -s, -
 	fi
done

