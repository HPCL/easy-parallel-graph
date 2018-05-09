#!/bin/bash
# Runs run-synthetic for each thread number.
# Must have called gen-datasets.sh beforehand
USAGE="usage: run-multi-thread.sh <scale> <dataset_file>
	(default dataset file: ../learn/datasets.txt)
	You can also change the THREADS variable in this script"
THREADS="1 2 4 8 16 24 32 40 48 56 64 72"
# THREADS="1 2" # Just for testing

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	echo "$USAGE"
	exit 2
fi
S="$1"
dataset_file="$2"
if [ -z "$dataset_file" ]; then
	dataset_file="../preprocess/datasets.txt"
fi

if [ -z "$S" ] || [ "$S" = '--help' ] || [ "$S" = '-h' ]; then
	echo "$USAGE"
	exit 2
fi

# Run realworld experiments
mkdir -p output
for T in $(echo $THREADS); do
	cnt=0
	while read -r line; do
		if [ ${line:0:1} = '#' ]; then # Ignore, it's a comment
			continue
		fi
		if [ "$(expr $cnt % 3 = 0)" -eq 1 ]; then
			dir_name="$line"
			mkdir -p "output/logs/$dir_name"
			echo "Running experiment on dataset $dir_name with $T threads"
			./real-datasets.sh "$dir_name" "$T" > "output/logs/$dir_name/${T}t.log" 2> "output/logs/$dir_name/${T}t.err"
		fi
	cnt=$(expr $cnt + 1)
	done < "$dataset_file"
done

# Run synthetic data
mkdir -p output/logs/kron-$S
for T in $(echo $THREADS); do
	echo "Running experiment on dataset kron-$S with $T threads"
	./run-synthetic.sh $S $T > output/logs/kron-${S}/${T}t.log 2> output/logs/kron-${S}/${T}t.err
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
