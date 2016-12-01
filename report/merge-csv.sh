#!/bin/bash
# Merges two csv files, given that they both only use one dataset for each run.
# To use with latex: ./merge-csv.sh > runtimes.csv

first=1
outfile=runtime.csv
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


