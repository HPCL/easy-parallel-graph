#!/bin/bash
# Runs run-experiment.sh for each thread number.
T=32
for S in $(echo 18 19 21); do
	./run-experiment.sh $S $T > out${S}-${T}.log 2> out${S}-${T}.err
done

