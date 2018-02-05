#!/bin/bash
# Download and build all the required graph processing libraries
USAGE="usage: get-libraries.sh <libdir>
	<libdir> repositories directory. Default: ./lib"
# TODO: Add a --power option which checks if $PAPI is defined
#       and by default builds in $(pwd)/powerlib

LIBDIR="$(pwd)/lib"
if [ -n "$1" ]; then
	LIBDIR="$1"
fi

FAILED=''
echo "Building RMAT generator"
cd ../RMAT
make
cd -
if [ "$?" -ne 0 ]; then FAILED="$FAILED RMAT"; fi

echo "Installing into $LIBDIR ..."

mkdir -p "$LIBDIR"
cd "$LIBDIR"
# GAP:
git clone https://github.com/sampollard/gapbs.git
cd gapbs; make
if [ "$?" -ne 0 ]; then FAILED="$FAILED GAP"; fi

# GraphBIG:
cd "$LIBDIR"
git clone https://github.com/sampollard/graphBIG.git
cd graphBIG/benchmark
make
if [ "$?" -ne 0 ]; then FAILED="$FAILED GraphBIG"; fi

# GraphMat:
cd "$LIBDIR"
git clone https://github.com/sampollard/GraphMat.git
cd GraphMat; make
if [ "$?" -ne 0 ]; then FAILED="$FAILED GraphMat"; fi

# Graph500:
cd "$LIBDIR"
git clone https://github.com/sampollard/graph500.git
cd graph500
echo "Building assuming you have gcc with OpenMP support."
cp make-incs/make.inc-gcc make.inc
ex -s make.inc "+:%s/gcc-4.6/gcc/g" "+:%s/# BUILD_OPENMP/BUILD_OPENMP/g" "+:%s/# CFLAGS_OPENMP/CFLAGS_OPENMP/g"  '+:x'
ex -s Makefile "+:%s/BUILD_RAPL = Yes/BUILD_RAPL = No/g" '+:x'
make
if [ "$?" -ne 0 ]; then FAILED="$FAILED Graph500"; fi

# PowerGraph:
# NOTE: Shared memory only!
cd "$LIBDIR"
git clone https://github.com/sampollard/PowerGraph
cd PowerGraph
./configure --no_jvm
cd release/toolkits/graph_analytics
# I could do -j4 but that tends to be buggy
make
if [ "$?" -ne 0 ]; then FAILED="$FAILED PowerGraph"; fi

# Galois:
cd "$LIBDIR"
wget -nc http://iss.ices.utexas.edu/projects/galois/downloads/Galois-2.2.1.tar.gz
tar -xf Galois-2.2.1.tar.gz
patch -p0 < galois.patch
cd "$LIBDIR/Galois-2.2.1"
cd build
mkdir -p default
cd default
gcc --version | grep -q '4\.8'
if [ $? -ne 0 ]; then
	echo "Galois requires gcc 4.8. You can comment out this check and try a lower version,
		but it doesn't seem to work at all with 4.9 or 5.*"
	exit 2
fi
cmake -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc ../..
make
cd "$LIBDIR/.."
if [ "$?" -ne 0 ]; then FAILED="$FAILED Galois"; fi

if [ -z "$FAILED" ]; then
	echo All libraries downloaded and built correctly.
else
	echo "$FAILED failed to load. Possible issues:"
	echo "This version of GraphMat requires icpc."
	echo "Galois is known to work with gcc 4.8.5 but has issues with gcc 4.9 or gcc 5.4.0. It's finicky.
	you can try others via -DCMAKE_CXX_COMPILER and -DCMAKE_C_COMPILER"
	echo "Your version of boost may cause issues as well; try using boost 1.55.0 or greater."
	echo "Other dependencies can be found in the README.md"
fi

# Others (maybe added later)
# PBGL: (not used here)
# module load boost/boost_1_62_0_gcc-5
# mpicxx -I/usr/local/packages/boost/1_62_0/gcc-5/include -L/usr/local/packages/boost/1_62_0/gcc-5/lib -o pbMST pbMST.cpp -lboost_graph_parallel -lboost_mpi -lboost_serialization -lboost_system
# export LD_LIBRARY_PATH=/usr/local/packages/boost/1_62_0/gcc-5/lib

