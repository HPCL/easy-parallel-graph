# Simplifying Parallel Graph Processing
```get-graphalytics.sh```: This script gathers, installs, and runs various
	benchmarks from Graphalytics. Run with no arguments. If you want to change
	what gets run, you can edit the script after the ```### MAIN ###``` section.

```get-gap.sh```: This script  gathers, installs, and runs the GraphBIG
	benchmark and compares it to Berkeley's GAP bechmark.

```get-hwinfo.sh```: Gathers hardware information and outputs to a csv (stdout). Meant to be used
	with the automatic report generation. Works better if you have sudo permission. Specifically,
	```sudo lshw > lshw.txt``` and ```sudo dmidecode > dmidecode.txt```

## Dependencies
A dependency will occur here no more than once. For example, GraphBIG requires maven but doesn't list it.
### This Script
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
