#!/bin/bash
# Runs run-experiment.sh for each thread number.
# Must have been parsed beforehand.
S=$1
THREADS="1 2 4 8 12 16 20 24 28 32"
if [ -z "$S" ] || [ "$S" = '--help' ] || [ "$S" = '-h' ]; then
	echo "usage: run-multi-thread.sh <scale>
	You can also change the THREADS variable in this script"
	exit 2
fi
mkdir -p output/out-kron-$S
for T in $(echo $THREADS); do
	./run-experiment.sh $S $T >> output/kron-${S}-logs/${T}t.log 2>> output/kron-${S}-logs/${T}t.err
done

