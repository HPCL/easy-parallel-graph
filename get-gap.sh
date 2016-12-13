#!/bin/bash

# Set and check where everything is going to be stored
# For SamXu2
#BASE_DIR="$HOME/uo/research/easy-parallel-graph"
#DATASET_DIR="$HOME/uo/research/datasets"
# For Arya
BASE_DIR="$HOME/gap"
DATASET_DIR="$HOME/graphalytics/all-datasets"
if [ -z "$BASE_DIR" ]; then
	echo "Please set BASE_DIR to be where all the benchmarks and output will be stored."
	exit 1;
elif [ -z "$DATASET_DIR" ]; then
	echo "Please set DATASET_DIR to be where the graphs are stored."
	exit 1
fi
cd "$BASE_DIR"

# Download and compile GAP Benchmark Suite
echo "Preparing GAP Benchmark Suite..."
if [ ! -d "$BASE_DIR/gapbs" ]; then
	git clone "https://github.com/spollard/gapbs.git" # Just until changes get merged
fi
GAPBS_DIR="$BASE_DIR/gapbs"
cd "$GAPBS_DIR"
make
make test
if [ $? -ne 0 ]; then
	echo "Some gapbs tests didn't pass"
	exit 1
fi

# Check for datasets
# They cannot be downloaded automatically. You must download them yourself :(
DATASETS=( Knowledge_Repo CA_RoadNet Watson_Gene )
FOUND=1
for d in "${DATASETS[@]}"; do
	if [ -z $(find "$DATASET_DIR" -type d -name "$d") ]; then
		FOUND=0
		echo "Could not find $d"
		break;
	fi
done
if [ $FOUND -eq 0 ]; then
	echo "Please download the datasets. This cannot be done noninteractively. They can be found at"
	echo "https://github.com/graphbig/graphBIG/wiki/GraphBIG-Dataset"
	exit 1
fi

### Run the benchmarks
# The general loop structure is a doubly-nested for loop
# looping over each dataset then each algorithm.

# TODO: Get other datasets converted to the right formats.
# Right now: LDBC Graphalytics datasets are not compatible since the edge numbers skip

# Set the names for the algorithms. They're not the same in GAP and GraphBIG.
# NOTE: GAP algorithms are the "canonical" algorithms; that's how the output files are named.
# NOTE: All algorithms must appear in the same order.
GAP_ALGORITHMS=( bfs pr sssp )
GRAPHBIG_ALGORITHMS=( bfs pagerank sssp )
ALGORITHM_DIRS=( bench_BFS bench_pageRank bench_shortestPath ) # Just used for GraphBIG

# Run GAP Benchmark
mkdir "$BASE_DIR/output"
for d in "${DATASETS[@]}"; do
	# Convert datasets into the correct format for GAP
	# Transform the datasets from GraphBIG (CSV) -> GAP ([w]el) format
	# GAP [w]el Format: one edge per line, either node1 node2 weight or just node1 node2
	awk -F ',' '{if (NR > 1) print $1 " " $2}' "$DATASET_DIR/$d/edge.csv" > "$DATASET_DIR/$d/$d.el"
	for ALG in "${GAP_ALGORITHMS[@]}"; do
		echo "Running GAP $ALG benchmark and saving the results to $BASE_DIR/output/${ALG}-GAP-$d.txt"
		./${ALG} -f "$DATASET_DIR/$d/$d.el" > "$BASE_DIR/output/${ALG}-GAP-$d.txt"
	done
done

# Download and compile GraphBIG Benchmark Suite
echo "Preparing GraphBIG..."
cd "$BASE_DIR"
if [ ! -d graphBIG ]; then
	git clone "https://github.com/graphbig/graphBIG.git"
fi
cd graphBIG/benchmark
make clean all

# Run GraphBIG Benchmark
for d in "${DATASETS[@]}"; do
	for i in $(seq ${#GRAPHBIG_ALGORITHMS[@]}); do
		CAN_ALG=${GAP_ALGORITHMS[$(($i-1))]} # CANononical ALGorithm name
		ALG=${GRAPHBIG_ALGORITHMS[$(($i-1))]}
		alg_dir=${ALGORITHM_DIRS[$(($i-1))]}
		echo "Running GraphBIG $ALG benchmark and saving the results to $BASE_DIR/output/${CAN_ALG}-graphBIG-$d.txt"
		# Use the randomly selected source vertices from GAP as the root vertices in GraphBIG
		# so the two tools are actually computing the same thing.
		SOURCES=$(awk '/Source/{print int($2)}' "$BASE_DIR/output/${CAN_ALG}-GAP-$d.txt")
		rm -f "$BASE_DIR/output/${ALG}-graphBIG-$d.txt" # Delete old runs
		if [ "$CAN_ALG" = "bfs" -o "$CAN_ALG" = "sssp" ]; then
			for source in $SOURCES; do
				"$alg_dir/$ALG" --dataset "$DATASET_DIR/$d" --root $source >> "$BASE_DIR/output/${CAN_ALG}-graphBIG-$d.txt"
			done
		elif [ "$CAN_ALG" = "pr" ]; then
			"$alg_dir/$ALG" --dataset "$DATASET_DIR/$d" >> "$BASE_DIR/output/${CAN_ALG}-graphBIG-$d.txt"
		else
			echo This algorithm is not implemented yet
			exit 1
		fi
	done
done

# Clean up
cd "$BASE_DIR"

