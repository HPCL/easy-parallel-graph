# Created using
# sudo singularity build epg.sif Singularity
# Code taken from https://github.com/ResearchIT/spack-singularity

BootStrap: library
From: ubuntu:16.04

%post
	cd opt
	export SPACK_ROOT=$(pwd)/spack
	export PATH=$SPACK_ROOT/bin/:$PATH
	echo spack root is $SPACK_ROOT, path is $PATH
	apt-get -y update

	apt-get -y install gcc g++ g++-4.8 gcc-4.8 gfortran-4.8
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 10
	update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.8 10

	apt-get -y install git curl wget vim python make cmake
	apt-get -y install gnupg2 sed patch unzip gzip bzip2 findutils environment-modules

	git clone https://github.com/spack/spack
	spack compiler find --scope system $(which gcc-4.8)

	git clone https://github.com/HPCL/easy-parallel-graph
	cd easy-parallel-graph/experiment
	export CC=gcc
	export CXX=g++
	./get-libraries.sh
	echo "Next I should install epg*"

%environment
	export SPACK_ROOT=$(pwd)/spack
	export PATH=$SPACK_ROOT/bin:$PATH
	source /etc/profile.d/modules.sh
	source $SPACK_ROOT/share/spack/setup-env.sh

%runscript
	echo "Downloaded epg*, checking spack"
	spack help

%test
	echo "Running test"
	cd easy-parallel-graph/experiment
	./gen-datasets.sh 12
	./run-experiment.sh 2 12

%labels
	MAINTAINER Samuel D. Pollard
	spack
	graph processing
