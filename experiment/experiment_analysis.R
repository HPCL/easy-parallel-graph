# Given the results from parse-output.sh, generate some plots of the data
usage <- "usage: Rscript experiment_analysis.R <config_file>"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
	stop(usage)
}
bpc <- "cyan"
prefix <- "./output/"

# source sets scale and threads
source(args[1]) # This is a security vulnerability... just be careful

# Assuming default edgefactor of 16
stopifnot(length(scale) == 1) # Not supported yet
algo <- "BFS"
for (th in threads) {
	nedges <- 16 * 2^scale
	filename <- paste0(prefix,"parsed-","kron-",scale,"-",th,".csv")
	x <- read.csv(filename, header = FALSE)
	colnames(x) <- c("Sys","Algo","Metric","Time")
	
	# Generate a figure
	algo_time <- subset(x, x$Algo == algo & x$Metric == "Time",
			c("Sys","Time"))
	algo_time$Time <- as.numeric(as.character(algo_time$Time))
	# Remove zero rows---they're invalid and don't work with the log plot
	# If some factors were coerced into NAs then there was some issue parsing
	algo_time <- algo_time[!algo_time$Time == 0.0, ]
	pdf(paste0("graphics/bfs_time", scale, "-", th, "t.pdf"),
		width = 5.2, height = 5.2)
	boxplot(Time~Sys, algo_time[,c("Time","Sys")], ylab = "Time (seconds)",
			main = "BFS Time", log = "y", col=bpc)
	mtext(paste0("nedges = ",nedges), side = 3)
	dev.off()
}

# UNIMPLEMENTED
# Weak scaling
# ws_scales <-  c(18,19,20,21,22,23,24)
# ws_threads <- c(1, 2, 4, 8, 16,32,64)
# for (t in ws_threads) {
# 	for (s in wc_scales) {
# 	}
# }

###
# Part 2: Generate the plots for a single algorithm and multiple problem sizes
###
measure_scale <- function(algo) {
    # Read in and average the data for BFS for each thread
    # It is wasteful to reread the parsed*-1t.csv but it simplifies the code
	filename <- paste0(prefix,"parsed-","kron-",scale,"-",t,".csv")
    x <- read.csv(filename, header = FALSE)
    colnames(x) <- c("Sys","Algo","Metric","Time")
    x$Sys <- factor(x$Sys, ordered = TRUE)
    systems <- levels(subset(x$Sys, x$Algo == algo, c("Sys")))
    algo_time <- data.frame(
            matrix(ncol = length(threads), nrow = length(systems)),
            row.names = systems)
    colnames(algo_time) <- threads
    for (ti in seq(length(threads))) {
        t <- threads[ti]
		filename <- paste0(prefix,"parsed-","kron-",scale,"-",t,".csv")
        Y <- read.csv(filename, header = FALSE)
        ti_time <- subset(Y, Y[[2]] == algo & Y[[3]] == "Time",
                c(V1,V4))
        algo_time[ti] <- aggregate(ti_time$V4, list(ti_time$V1), mean)[[2]]
    }
    return(algo_time)
}

bfs_scale <- measure_scale("BFS") # Possiblities: BFS, SSSP, PageRank
colors <- rainbow(nrow(bfs_scale))
colors <- gsub("F", "C", colors) # You want it darker
colors <- gsub("CC$", "FF", colors) # But keep it opaque
bfs_ss <- bfs_scale
# Strong scaling for sequential is 1---we compute that last
for (ti in rev(seq(length(threads)))) {
	bfs_ss[ti] <- bfs_ss[1] / (threads[ti] * bfs_ss[ti])
}

print(bfs_ss) # TEST

