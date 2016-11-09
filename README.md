# Making Graph Benchmarking Easy
This script gathers, installs, and runs various benchmarks from Graphalytics.

## Dependencies
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
2. CUDA SDK 5.5 or greater
3. For profiling: Linux (because it uses libpfm) 
4. Cmake

### GraphX
1. Hadoop binary saved in some directory OR Hadoop already running
2. Java JDK 1.6 or newer
3. If running on one node for hadoop: ability to ssh into localhost without a password

### PowerGraph
