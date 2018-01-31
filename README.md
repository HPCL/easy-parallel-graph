# Simplifying Parallel Graph Processing

This project is aimed at simplifying aspects of parallel graph processing starting with providing a framework for analyzing performance and energy usage for a given system.

The general workflow could consist of the following steps. You can find an example workflow in `experiments/example-workflow.sh`.

0. `cd experiment`
1. Download the systems and build them with `./get-libraries.sh`. You may also supply a location where the libraries should be installed but the default is `./lib`.
2. Generate some synthetic datasets with `./gen-datasets.sh 20`. The 20 here will generate an RMAT matrix to the Graph500 specifications with 2^20 = 1,048,576 vertices with an average of 16 edges per vertex.
	* Alternatively, you could run `./gen-datasets -f=<your_file>`. Currently, this only supports files of the `.el` and `.wel` forms. These are explained [here](https://gist.github.com/sampollard/f9169c4eb04669390a834884682c080d). It should accept any graph file you can find from [SNAP Database](https://snap.stanford.edu/data/index.html) or the [KONECT Database](http://konect.uni-koblenz.de/networks/).
3. Select a scale and number of threads and run the experiment with `run-experiment.sh`, e.g.
```./run-experiment.sh 20 4```
4. Parse the log files to get a .csv using `./parse-output.sh`
	* Note: `run-power.sh` also parses the log files.
5. Analyze the data. Some examples can be found in `papers/publication/plot_data.R` and`experiment/experiment_analysis.R`.

## Algorithms
1. Breadth First Search (BFS)
2. Single Source Shortest Paths (SSSP)
3. PageRank: This uses a stopping criterion of `sum(|π_i - π_(i-1)|)` where `π_i` is the PageRank at iteration `i` and the alpha parameter is ɑ = 0.15.
4. Triangle Counting (TriangleCount) - Counts the number of triangles in an undirected graph. If the input graph is directed, it is symmetrized beforehand.

## Power and Energy
If you want to build for power measurement, you may use `power/build-power.sh`
Run the experiments and monitor power using `experiment/run-power.sh`. Requires root permissions.
`build-power.sh` downloads and compiles the various projects for power measurement. Installs to `./powerlib` by default.

## Analysis
`experiment_analysis.R:` This script takes in a config file. You can see an example in `config_template.R`. Notice here there are both synthetic and realworld experiments that can be analyzed at once. If you just want to do one or the other, uncomment out `focus_scale` and `focus_thread` for synthetic and `realworld_datasets` for realworld datasets.

### Other Scripts
`graphalytics/get-graphalytics.sh`: This script gathers, installs, and runs various
	benchmarks from Graphalytics. Run with no arguments. If you want to change
	what gets run, you can edit the script after the `### MAIN ###` section.

`papers/report/get-hwinfo.sh`: Gathers hardware information and outputs to a csv (stdout). Meant
	to be used with the automatic report generation. Works better if you have sudo permission.
	Specifically, `sudo lshw > lshw.txt` for Linux and `sudo dmidecode > dmidecode.txt` for Mac.

## Dependencies
### The Scripts in the `experiment` Directory
1. R and the ggplot2 library
2. Graph500, GAP, Graphalytics, GraphBIG, PowerGraph dependencies

### GraphBIG/OpenG
1. gcc/g++ with c++0x support (>4.3)
2. For profiling: Linux (because it uses libpfm) 
3. Cmake

### PowerGraph
1. zlib
2. MPICH2

### GraphMat
1. Intel compiler (icpc 17 is known to work, but icpc 15 may not)

### Graph500 & GAP Benchmark Suite
1. A C++ compiler with OpenMP Support

## Features that are not ready

### Graphalytics
You can download and build the systems for Graphalytics, package them, and run them with `graphalytics/get-graphalytics.sh`.

### `get-graphalytics.sh`
1. Java
2. Bash
3. Perl
4. Yarn
5. Apache maven 3.0.0 or later
6. Git

### Graphalytics
1. Apache maven 3.0.0 or later
