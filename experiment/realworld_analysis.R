library(ggplot2)
# Given the results from parse-output.sh,
# tabulate and generate some plots.
usage <- "usage: Rscript experiment_analysis.R <config_file>"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
	stop(usage)
}
prefix <- "./output/" # The default.

# source should set dataset_list and threads
source(args[1]) # This is a security vulnerability... only run trusted files.

# Tabulate the average runtime and data set
avgs <- tabulate_data <- function(thr, dataset)
{
	filename <- paste0(prefix,"parsed-",dataset,"-",thr,".csv")
	x <- read.csv(filename, header = FALSE)
	colnames(x) <- c("Sys","Algo","Metric","Time")
	avgs <- aggregate(x$Time, list(x$Sys, x$Algo, x$Metric), mean)
	return(avgs)
}

# Compare datasets using one metric where
# metric %in% c("Data structure build", "File reading", "Iterations", "Time")
# (Iterations only makes sense for PageRank)
# Supported options for algo: "BFS", "SSSP", "PageRank"
compare_datasets <- function(all_avgs, dataset_list, algo, metric = "Time")
{
	# If you just want a single algorithm, remove the "facet_wrap" line and use
	# avgs.m.a <- subset(all_avgs, all_avgs$Metric==metric & all_avgs$Algo==algo)
	avgs.m <- subset(all_avgs, all_avgs$Metric==metric)
	p <- ggplot(avgs.m, aes(Dataset, Time, fill = Sys)) +
			geom_bar(stat = "identity", position = "dodge") +
			facet_wrap(~Algo, scales = "free") +
			# If your datasets are too long you can rename them
			scale_x_discrete(labels = c("dota","Patents")) +
			theme(axis.text.x = element_text(angle = 30, hjust = 1))
	pdf(paste0("graphics/compare-",metric,".pdf"),
		width = 5, height = 3)
	p
	dev.off()
}

all_avgs <- data.frame()
thr <- threads[1] # Just start with one thread count
for (dset in dataset_list) {
	avgs <- tabulate_data(thr, dset)
	all_avgs <- rbind(all_avgs, cbind(dset, avgs))
}
colnames(all_avgs) <- c("Dataset","Sys","Algo","Metric","Time")

compare_datasets(all_avgs, dataset_list, "SSSP")

