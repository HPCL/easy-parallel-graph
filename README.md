# Simplifying Parallel Graph Processing

This project is aimed at simplifying aspects of parallel graph processing starting with providing a framework for analyzing performance and energy usage for a given system. I am attempting to keep the README updated but the most up to date information is usually inside the comments of the various shell scripts.

Below are some relevant scripts.

## Easy Parallel Graph Method
```experiment/gen-datasets.sh``` This script generates the dataset based on the Graph500 specification and executable, then converts the data into the correct formats for GAP, GraphBIG, and GraphMat. It requires GraphMat and Graph500 repositories to be built and their paths set as variables in the script. usage: ```gen-datasets.sh <S>``` where 2^S is the number of vertices.

```experiment/run-experiment.sh``` This script takes no arguments, but several variables must be set inside of it. It also expects ```gen-datasets.sh``` has been run at the given scale. There are comments inside this script on how to get each system built.
usage: ```run-experiment <S> <num-threads>```

## Other Scripts
```get-graphalytics.sh```: This script gathers, installs, and runs various
	benchmarks from Graphalytics. Run with no arguments. If you want to change
	what gets run, you can edit the script after the ```### MAIN ###``` section.

```get-gap.sh```: This script  gathers, installs, and runs the GraphBIG
	benchmark and compares it to Berkeley's GAP bechmark. The performance results are somewhat limited.

```get-hwinfo.sh```: Gathers hardware information and outputs to a csv (stdout). Meant to be used
	with the automatic report generation. Works better if you have sudo permission. Specifically,
	```sudo lshw > lshw.txt``` for Linux and ```sudo dmidecode > dmidecode.txt``` for Mac.

## Dependencies
### get-graphalytics.sh
1. Bash
2. Perl
3. Yarn
4. Apache maven 3.0.0 or later
5. Git
6. wget
7. Two variables: ```HADOOP_HOME``` (where hadoop is installed) and ```BASE_DIR``` (where you want graphalytics to put everything).

### Graphalytics
1. Apache maven 3.0.0 or later

### GraphBIG/OpenG
1. gcc/g++ with c++0x support (>4.3)
2. CUDA SDK 5.5 or greater for the cpu_bench (Not currently supported)
3. For profiling: Linux (because it uses libpfm) 
4. Cmake

### GraphX
1. Hadoop binary saved in some directory OR Hadoop already running
2. Java JDK 1.6 or newer
3. If running on one node for hadoop: ability to ssh into localhost without a password

### PowerGraph
1. zlib
2. MPICH2

### GraphMat
1. Intel compiler (icpc 17 is known to work, but icpc 15 may not)

