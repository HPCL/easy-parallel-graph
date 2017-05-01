#!/bin/bash
# Download and build all the required graph processing libraries
USAGE="usage: get-libraries.sh <libdir>
	<libdir> repositories directory. Default: ./lib"

LIBDIR="$(pwd)/lib"
if [ -n "$1" ]; then
	LIBDIR="$1"
fi
echo "Installing into $LIBDIR ..."

mkdir -p "$LIBDIR"
cd "$LIBDIR"
# GAP:
git clone https://github.com/sampollard/gapbs.git
cd gapbs; make

# GraphBIG:
cd "$LIBDIR"
git clone https://github.com/sampollard/graphBIG.git
cd graphBIG; make
cd GraphBIG/benchmark
make clean all

# GraphMat:
cd "$LIBDIR"
module load intel/17
git clone https://github.com/sampollard/GraphMat.git
cd GraphMat; make

# Graph500:
cd "$LIBDIR"
git clone https://github.com/sampollard/graph500.git
cd graph500
echo "Building assuming you have gcc with OpenMP support."
cp make-incs/make.inc-gcc make.inc
ex -s make.inc "+:%s/gcc-4.6/gcc/g" "+:%s/# BUILD_OPENMP/BUILD_OPENMP/g" "+:%s/# CFLAGS_OPENMP/CFLAGS_OPENMP/g"  '+:x'
ex -s Makefile "+:%s/BUILD_RAPL = Yes/BUILD_RAPL = No/g" '+:x'
make

# PowerGraph:
# NOTE: Shared memory only!
cd "$LIBDIR"
git clone https://github.com/sampollard/PowerGraph
cd PowerGraph
./configure --no_jvm
cd release/toolkits/graph_analytics
# I could do -j4 but that tends to be buggy
make
cd "$LIBDIR"

# Others (maybe added later)
# PBGL: (not used here)
# 	module load boost/boost_1_62_0_gcc-5
# 	mpicxx -I/usr/local/packages/boost/1_62_0/gcc-5/include -L/usr/local/packages/boost/1_62_0/gcc-5/lib -o pbMST pbMST.cpp -lboost_graph_parallel -lboost_mpi -lboost_serialization -lboost_system
# 	export LD_LIBRARY_PATH=/usr/local/packages/boost/1_62_0/gcc-5/lib

# Galois:
# wget http://iss.ices.utexas.edu/projects/galois/downloads/Galois-2.2.1.tar.gz
