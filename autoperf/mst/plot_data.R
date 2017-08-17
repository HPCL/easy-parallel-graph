# Given some output from ./run experiment then ./run parse
# generate some plots of the data
usage <- "usage: Rscript experiment_analysis.R <parsed_csv>"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
	stop(usage)
}
bpc <- "cyan"

# Source provides scale and threads
filename <- args[1]
x <- read.csv(filename, header = TRUE)
# Header:
# algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
scale <- 24
pct_ins <- 75
total_time <- subset(x,
		x$execution_phase == "All" & x$scale == scale & x$insertion_percent == pct_ins,
		c("algorithm","value"))
time_cols <- c("algorithm","value")
total_time$algorithm <- as.character(total_time$algorithm)
pdf(paste0("cc_",scale,"_",pct_ins,"ins.pdf"))
boxplot(value~algorithm, data = total_time, ylab = "Time (seconds)",
			main = paste("MST Total Time for scale",scale, ",", pct_ins, "% insertions", col="green")
dev.off()

# Assuming default edgefactor of 16
# for (t in threads) {
# 	print(paste0("Reading from ",filename))
# 
# 	colnames(x) <- c("Sys","Algo","Metric","Time")
# 	
# 	# Generate a figure
# 	bfs_time <- subset(x, x$Algo == "BFS" & x$Metric == "Time",
# 			c("Sys","Time"))
# 	pdf(paste0("graphics/bfs_time", scale, "-", t, "t.pdf"),
# 		width = 5.2, height = 5.2)
# 	# The error 'adding class "factor" to an invalid object' probably means
# 	# there was an error parsing so that extra entries were printed.
# 	# this is caused by having too much in your log files. Just delete
# 	# your output/kron-scale directory and start over
# 	x <- read.csv(filename, header = FALSE)
# 	boxplot(Time~Sys, bfs_time[,c("Time","Sys")], ylab = "Time (seconds)",
# 			main = "BFS Time", log = "y", col=bpc)
# 	mtext(paste0("nedges = ",nedges), side = 3)
# 	dev.off()
# }
# 
