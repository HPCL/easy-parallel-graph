# Config template for experiment_analysis.R. This is to be run after you have
# run and parsed experiments. This gets sourced by experiment_analysis.R.

prefix <- './output/'       # Choose this to be where your parsed output is stored. Other scripts use this default.
focus_scale <- 22           # Kronecker graph size (2^scale vertices) over which analysis is done.
threads <- c(1,2,4,8,16,32,64,72) # Select a range of threads over which to measure scalability
focus_thread <- 32          # Pick a thread count for more detailed analysis (generate timing plots)

# Whether to coalese performance data into one giant CSV (useful for input to machine learning).
# Any variables following coalesce are only used if coalesce is TRUE.
coalesce <- TRUE
coalesce_filename <- paste0(prefix,'combined.csv')
kron_scales <- c(10,13,22)  # Select whichever scales on which you ran the synthetic datasets
