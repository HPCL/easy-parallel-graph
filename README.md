# Simplifying Parallel Graph Processing

This project is aimed at simplifying aspects of parallel graph processing starting with providing a framework for analyzing performance and energy usage for a given system.

The general workflow could consist of the following steps. Each script is explained in further detail in the following sections.

0. cd experiment
1. Download the systems and build them with `./get-libraries.sh`. You may also supply a location where the libraries should be installed but the default is `./lib`.
2. Generate some synthetic datasets with `./gen-datasets.sh 20`. The 20 here will generate an RMAT matrix to the Graph500 specifications with 2^20 = 1,048,576 vertices with an average of 16 edges per vertex.
	* Alternatively, you could run `./gen-datasets -f=<your_file>`. Currently, this only supports files of the `.el` and `.wel` forms. These are explained [here](https://gist.github.com/sampollard/f9169c4eb04669390a834884682c080d). It should accept any graph file you can find from [SNAP Dataset](https://snap.stanford.edu/data/index.html) too.
4. Select a scale and number of threads and run the experiment with `run-experiment.sh`, e.g. `./run-experiment.sh 20 4`
5. Parse the log files to get a .csv using `parse-output.sh`
	* Note: `run-power.sh` also parses the log files.
6. TODO: Generate some figures and analyze the data with `plot_data.R`.

### Graphalytics
You can download and build the systems for Graphalytics, package them, and run them with `graphalytics/get-graphalytics.sh`.

### Power and Energy
If you want to build for power measurement, you may use `power/build-power.sh`
Run the experiments and monitor power using `experiment/run-power.sh`. Requires root permissions.
Below are some relevant scripts.

## "Easy Parallel Graph" Approach
`experiment/gen-datasets.sh` This script generates the dataset based on the Graph500 specification and executable, then converts the data into the correct formats for GAP, GraphBIG, and GraphMat. It requires GraphMat and Graph500 repositories to be built and their paths set as variables in the script. usage: `gen-datasets.sh <S>` where 2^S is the number of vertices.

`experiment/run-experiment.sh` This script takes no arguments, but several variables must be set inside of it. It also expects `gen-datasets.sh` has been run at the given scale. There are comments inside this script on how to get each system built.
usage: `run-experiment <S> <num-threads>`

## Other Scripts
`graphalytics/get-graphalytics.sh`: This script gathers, installs, and runs various
	benchmarks from Graphalytics. Run with no arguments. If you want to change
	what gets run, you can edit the script after the `### MAIN ###` section.

`build-power.sh`:  This script downloads and compiles the various projects for power measurement.

`papers/report/get-hwinfo.sh`: Gathers hardware information and outputs to a csv (stdout). Meant
	to be used with the automatic report generation. Works better if you have sudo permission.
	Specifically, `sudo lshw > lshw.txt` for Linux and `sudo dmidecode > dmidecode.txt` for Mac.

## Dependencies
### get-graphalytics.sh
1. Bash
2. Perl
3. Yarn
4. Apache maven 3.0.0 or later
5. Git
6. wget
7. Two variables: `HADOOP_HOME` (where hadoop is installed) and `BASE_DIR` (where you want graphalytics to put everything).

### Graphalytics
1. Apache maven 3.0.0 or later

### GraphBIG/OpenG
1. gcc/g++ with c++0x support (>4.3)
2. CUDA SDK 5.5 or greater for `gpu_bench` (Not currently supported)
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

