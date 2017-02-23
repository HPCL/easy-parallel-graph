#!/bin/bash
# Runs run-experiment.sh for each thread number.
S=$1
if [ -z "$S" ]; then
	echo "usage: run-multi-thread.sh <scale>"
	exit 2
fi
for T in $(echo 1 2 4 8 16 32 64 72); do
	./run-experiment.sh $S $T >> out${S}-${T}.log 2>> out${S}-${T}.err
done

