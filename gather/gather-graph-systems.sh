#!/bin/bash
# Download and build graph processing systems.

## Dependencies:
### Spack
#### Python 2.6 or 2.7, a C/C++ Compiler, git, and curl
### AnotherGraphPunPackage

export SPACK_ROOT= # You should set this
if [ -n $SPACK_ROOT ]
	source $SPACK_ROOT/share/spack/setup-env.sh
fi
if command -v spack || [ -n $SPACK_ROOT ]; then
	echo You must have spack in your PATH or set SPACK_ROOT
	echo This can be done by following the following guide:
	echo http://spack.readthedocs.io/en/latest/getting_started.html
	echo If you use modules or you should also run
	echo 'source $SPACK_ROOT/share/spack/setup-env.sh'
	exit 2
fi

