# Given the results from parse-output.sh, generate some plots of the data
usage <- "usage: Rscript experiment_analysis.R <config_file>"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
	stop(usage)
}
bpc <- "cyan"

# Source provides scale and threads
source(args[1]) # This is a security vulnerability... just be careful

# Assuming default edgefactor of 16
stopifnot(length(scale) == 1) # Not supported yet
for (t in threads) {
	nedges <- 16 * 2^scale
	filename <- paste0("./output/parsed-","kron-",scale,"-",t,".csv")
	print(paste0("Reading from ",filename))

	x <- read.csv(filename, header = FALSE)
	colnames(x) <- c("Sys","Algo","Metric","Time")
	
	# Generate a figure
	bfs_time <- subset(x, x$Algo == "BFS" & x$Metric == "Time",
			c("Sys","Time"))
	pdf(paste0("graphics/bfs_time", scale, "-", t, "t.pdf"),
		width = 5.2, height = 5.2)
	# The error 'adding class "factor" to an invalid object' probably means
	# there was an error parsing so that extra entries were printed.
	# this is caused by having too much in your log files. Just delete
	# your output/kron-scale directory and start over
	x <- read.csv(filename, header = FALSE)
	boxplot(Time~Sys, bfs_time[,c("Time","Sys")], ylab = "Time (seconds)",
			main = "BFS Time", log = "y", col=bpc)
	mtext(paste0("nedges = ",nedges), side = 3)
	dev.off()
}

