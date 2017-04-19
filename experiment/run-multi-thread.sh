#!/bin/bash
# Runs run-experiment.sh for each thread number.
# Must have been parsed beforehand.
S=$1
if [ -z "$S" ]; then
	echo "usage: run-multi-thread.sh <scale>"
	exit 2
fi
for T in $(echo 1 2 4 8 16 32 64 72); do
	./run-experiment --ddir=$HOME/graphalytics/all-datasets/gabb17 --libdir=$HOME/graphalytics $S $T >> output/out${S}-${T}.log 2>> output/out${S}-${T}.err
done

# Other experiment examples on arya:
# ./gen-datasets.sh --libdir=$LIBDIR --ddir=$DDIR $S
# ./run-experiment.sh $S $T --libdir=$LIBDIR --ddir=$DDIR > output/out${S}-${T}.log 2> output/out${S}-${T}v2.err &
# ./run-power.sh --ddir=$DDIR $S $T
