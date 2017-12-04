#!/bin/bash
# Runs run-experiment.sh for each thread number.
# Must have called gen-datasets.sh beforehand
S=$1
THREADS="1 2 4 8 16 24 32 40 48 54 64 72"
if [ -z "$S" ] || [ "$S" = '--help' ] || [ "$S" = '-h' ]; then
	echo "usage: run-multi-thread.sh <scale>
	You can also change the THREADS variable in this script"
	exit 2
fi
mkdir -p output/logs/kron-$S
for T in $(echo $THREADS); do
	./run-experiment.sh $S $T > output/logs/kron-${S}/${T}t.log 2> output/logs/kron-${S}/${T}t.err
done

mkdir -p output
dataset_file="../learn/datasets.txt"
for T in $(echo $THREADS); do
	cnt=0
	while read -r line; do
		if [ ${line:0:1} = '#' ]; then # Ignore, it's a comment
			continue
		fi
		if [ "$(expr $cnt % 3 = 0)" -eq 1 ]; then
			dir_name="$line"
			mkdir -p "output/logs/$dir_name"
			./real-datasets.sh "$dir_name" "$T" > "output/logs/$dir_name/${T}t.log" 2> "output/logs/$dir_name/${T}t.err"
		fi
	cnt=$(expr $cnt + 1)
	done < "$dataset_file"
done

# Parse the output
for T in $(echo $THREADS); do
	cnt=0
	while read -r line; do
		if [ ${line:0:1} = '#' ]; then # Ignore, it's a comment
			continue
		fi
		if [ "$(expr $cnt % 3 = 0)" -eq 1 ]; then
			dir_name="$line"
			./parse-output.sh -f="datasets/$dir_name"
		fi
	cnt=$(expr $cnt + 1)
	done < "$dataset_file"
done
