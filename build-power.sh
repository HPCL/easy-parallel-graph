#!/bin/bash
# Compiles and runs the experiments for power measurement
# NOTE: This should just be used for building
# and run-power.sh for experiment running.

# Set and check where everything is going to be stored
BASE_DIR=
DATASET_DIR=
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
	git clone https://github.com/spollard/gapbs.git
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
	git clone "https://github.com/sampollard/graphBIG.git"
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
	git clone https://github.com/sampollard/GraphMat.git
fi
cd GraphMat
sed -i 's/BUILD_RAPL = No/BUILD_RAPL = Yes/' Makefile
make

# Clean up
cd "$BASE_DIR"

