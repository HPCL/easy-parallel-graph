#!/bin/bash
# Compiles and runs the experiments for power measurement
# NOTE: This should just be used for building
# and run-power for experiment running.
RUN_EXPERIMENTS=false

# Set and check where everything is going to be stored
# For SamXu2
#BASE_DIR="$HOME/uo/research/easy-parallel-graph"
#DATASET_DIR="$HOME/uo/research/datasets"
# For Arya
BASE_DIR="$HOME/power"
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
sed -i 's/BUILD_RAPL = No/BUILD_RAPL = Yes/' Makefile
make
make test
if [ $? -ne 0 ]; then
	echo "Some gapbs tests didn't pass"
	exit 1
fi

# Download and compile GraphBIG Benchmark Suite
echo "Preparing GraphBIG..."
cd "$BASE_DIR"
if [ ! -d graphBIG ]; then
	git clone "https://github.com/HPCL/graphBIG.git"
fi
cd graphBIG/benchmark
sed -i 's/BUILD_RAPL = No/BUILD_RAPL = Yes/' common.mk
make clean all

# Download and compile Graph500
echo "Preparing GraphBIG..."
cd "$BASE_DIR"
if [ ! -d graphBIG ]; then
	git clone https://github.com/sampollard/graph500.git
fi
cd graph500
cp make-incs/make.inc-gcc make.inc
sed -i 's/# BUILD_OPENMP = Yes/BUILD_OPENMP = Yes/' make.inc
sed -i 's/# CFLAGS_OPENMP = -fopenmp/CFLAGS_OPENMP = -fopenmp/' make.inc
sed -i 's/BUILD_RAPL = No/BUILD_RAPL = Yes/' Makefile
sed -i 's/gcc-4\.6/gcc/' make.inc
make

# Download and compile GraphMat
echo "Preparing GraphMat..."
cd "$BASE_DIR"
if [ ! -d GraphMat ]; then
	git clone https://github.com/HPCL/GraphMat.git
fi
cd GraphMat
sed -i 's/BUILD_RAPL = No/BUILD_RAPL = Yes/' Makefile
make

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

# Transform datasets from Graphalytics format to GraphBIG format
# (We later transform from GraphBIG to GAP)
GRAPHALYTICS_DATASETS=( dota-league cit-Patents )
for d in ${GRAPHALYTICS_DATASETS[@]}; do
	mkdir -p "$DATASET_DIR/$d"
	if [ $(awk '{print NF; exit}' "$DATASET_DIR/$d.e") -eq 2 ]; then
		echo "SRC,DEST" > "$DATASET_DIR/$d/edge.csv"
	elif [ $(awk '{print NF; exit}' "$DATASET_DIR/$d.e") -eq 3 ]; then
		echo "SRC,DEST,WEIGHT" > "$DATASET_DIR/$d/edge.csv"
	else
		echo "File format not recognized"
		exit 1
	fi
	sed 's/[:space:]+/,/' "$DATASET_DIR/$d.e" >> "$DATASET_DIR/$d/edge.csv"
	echo "ID" > "$DATASET_DIR/$d/vertex.csv"
	sed 's/[:space:]+/,/' "$DATASET_DIR/$d.v" >> "$DATASET_DIR/$d/vertex.csv"
done

# Set the names for the algorithms. They're not the same in GAP and GraphBIG.
# NOTE: GAP algorithms are the "canonical" algorithms; that's how the output files are named.
# NOTE: All algorithms must appear in the same order.
GAP_ALGORITHMS=( bfs pr sssp )
GRAPHBIG_ALGORITHMS=( bfs pagerank sssp )
ALGORITHM_DIRS=( bench_BFS bench_pageRank bench_shortestPath ) # Just used for GraphBIG

### Run the benchmarks
# The general loop structure is a doubly-nested for loop
# looping over each dataset then each algorithm.

if [ $RUN_EXPERIMENTS = false ]; then
	echo "No experiments run."
	exit 0
fi

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

# Run GraphBIG Benchmark
for d in "${DATASETS[@]}"; do
	for i in $(seq ${#GRAPHBIG_ALGORITHMS[@]}); do
		CAN_ALG=${GAP_ALGORITHMS[$(($i-1))]} # CANonical ALGorithm name
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

# TODO: Run the PowerGraph benchmark.
# We do this instead of graphalytics?
# Graphalytics measures the time of reading the graph.

# Clean up
cd "$BASE_DIR"

