# Config template for experiment_analysis.R. This is to be run after you have
# run and parsed experiments. This gets sourced by experiment_analysis.R.

prefix <- './output/'       # Choose this to be where your parsed output is stored. Other scripts use this default.
# Both focus_scale and focus_thread must be uncommented to generate _any_ figures.
#focus_scale <- 22          # Kronecker graph size (2^scale vertices) over which analysis is done.
#focus_thread <- 32         # Pick a thread count for more detailed analysis (generate timing plots).
threads <- c(1,2,4,8,16,24,32,40,48,56)    # Select a range of threads over which to measure scalability
algos <- c("BFS","SSSP","PageRank")        # Which algorithms you ran experiments for. (currently not "TC")

# Whether to coalese performance data into one giant CSV (useful for input to machine learning).
# Any variables following coalesce are only used if coalesce is TRUE.
coalesce <- TRUE
ignore_extra_features <- FALSE # Whether to use features.csv for realworld datasets. Default: FALSE
coalesce_filename <- paste0(prefix,'combined.csv') # Where to save the combination of all the files
data_dir <- "datasets"     # The directory where the datasets (and features) are stored
kron_scales <- c(13)       # Select whichever scales on which you ran the synthetic datasets
rmat_params <- c("*")      # Which rmat parameters to use. Same format as in gen-datasets.sh, e.g. "0.5 0.2 0.2". Use "*" for all or comment out for default

# Selects the realworld datasets on which you ran experiments
# These are expected to be inside data_dir
realworld_datasets <- c('dota-league')

# Here is a more complex example, such as if you downloaded the datasets and automated that part.
# From datasets.txt we want just the directory names, which are every 3rd line, ignoring comments
#realworld_datasets <- read.csv('../preprocess/datasets.txt', header = FALSE, comment.char = "#")
#realworld_datasets <- as.character(realworld_datasets[seq(1, nrow(realworld_datasets), 3), 1])

