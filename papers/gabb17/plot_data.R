# Generate some plots using the data parsed by ../../misc/parse-output.sh
# Make this section be the results from the optimal number of threads
# TODO: Make the first filename compared the highest-performing one.
scale <- 20
bpc <- "cyan"
filename <- paste0("parsed",scale,".csv")
x <- read.csv(filename, header = FALSE)
colnames(x) <- c("Sys","Algo","Metric","Time")

bfs_time <- subset(x, x$Algo == "BFS" & x$Metric == "Time",
		c("Sys","Time"))
bfs_dsc <- subset(x, x$Algo == "BFS" & x$Metric == "Data structure build",
		c("Sys","Time"))
bfs_dsc$Sys <- factor(bfs_dsc$Sys)

sssp_time <- subset(x, x$Algo == "SSSP" & x$Metric == "Time",
		c("Sys","Time"))
sssp_dsc <- subset(x, x$Algo == "SSSP" & x$Metric == "Data structure build",
		c("Sys","Time"))
sssp_time$Sys <- factor(sssp_time$Sys)
sssp_dsc$Sys <- factor(sssp_dsc$Sys)

pr_time <- subset(x, x$Algo == "PageRank" & x$Metric == "Time",
		c("Sys","Time"))
pr_dsc <- subset(x, x$Algo == "PageRank" & x$Metric == "Data structure build",
		c("Sys","Time"))
pr_iters <- subset(x, x$Algo == "PageRank" & x$Metric == "Iterations",
		c("Sys","Time"))
pr_time$Sys <- factor(pr_time$Sys)
pr_dsc$Sys <- factor(pr_dsc$Sys)

pdf("graphics/bfs_time.pdf", width = 5.2, height = 5.2)
boxplot(Time~Sys, bfs_time, ylab = "Time (seconds)",
		main = "BFS Time", log = "y", col=bpc)
dev.off()

pdf("graphics/bfs_dsc.pdf", width = 4.5, height = 4.5)
boxplot(Time~Sys, bfs_dsc, ylab = "Time (seconds)",
		main = "BFS Data Structure Construction", col=bpc, log = "y")
dev.off()

pdf("graphics/sssp_time.pdf", width = 4.5, height = 4.5)
boxplot(Time~Sys, sssp_time, ylab = "Time (seconds)",
		main = "SSSP Time", log = "y", col=bpc)
dev.off()

pdf("graphics/sssp_dsc.pdf", width = 4.5, height = 4.5)
boxplot(Time~Sys, sssp_time, ylab = "Time (seconds)",
		main = "SSSP Data Structure Construction", log = "y", col=bpc)
dev.off()

pdf("graphics/pr_time.pdf", width = 4.5, height = 4.5)
boxplot(Time~Sys, pr_time, ylab = "Time (seconds)",
		main = "PageRank Time", log = "y", col=bpc)
dev.off()

pdf("graphics/pr_iters.pdf", width = 4.5, height = 4.5)
pr_mean_iters <- c(
		mean(pr_iters$Time[pr_iters$Sys == "GraphBIG"]),
		mean(pr_iters$Time[pr_iters$Sys == "GraphMat"]),
		mean(pr_iters$Time[pr_iters$Sys == "GAP"]))
barplot(pr_mean_iters, ylab = "Time (second)",
		main = "PageRank Iterations", col=c("green","orange","cyan"),
		names.arg = unique(pr_iters$Sys))
dev.off()

# This isn't kind of wasteful to reread the *-1.csv but it simplifies the code
threadcnts <- c(1,2,4)
x <- read.csv(paste0("parsed",scale,"-1.csv"), header = FALSE)
colnames(x) <- c("Sys","Algo","Metric","Time")
systems <- unique(x$Sys)
bfs_scale <- data.frame(
		matrix(ncol = length(threadcnts), nrow = length(systems)),
		row.names = systems)
colnames(bfs_scale) <- threadcnts
for (ti in seq(length(threadcnts))) {
	thread <- threadcnts[ti]
	Y <- read.csv(paste0("parsed",scale,"-",thread,".csv"),
			header = FALSE)
	bfs_time <- subset(Y, Y[[2]] == "BFS" & Y[[3]] == "Time",
			c(V1,V4))
	bfs_scale[ti] <- aggregate(bfs_time$V4, list(bfs_time$V1), mean)[[2]]
}

# Plot the strong scalability for BFS
pdf("graphics/bfs_ss.pdf", width = 4.5, height = 4.5)
bfs_ss <- bfs_scale
colors <- rainbow(nrow(bfs_ss))
colors <- gsub("F", "C", colors) # You want it darker
par(lwd = 3)
# Strong scaling for sequential is 1---we compute that last
for (ti in rev(seq(length(threadcnts)))) {
	bfs_ss[ti] <- bfs_ss[1] / (threadcnts[ti] * bfs_ss[ti])
}
plot(as.numeric(bfs_ss[1,]), xaxt = "n", type = "b", ylim = c(0,1),
		ylab = "Scalability", xlab = "Threads", col = colors[1],
		main = "BFS Strong Scaling", lty = 1)
for (pli in seq(2,nrow(bfs_ss))) {
	lines(as.numeric(bfs_ss[pli,]), col = colors[pli], type = "b",
		lty = pli) # XXX: May break after 8
}
axis(1, at = seq(length(threadcnts)), labels = threadcnts)
legend(legend = rownames(bfs_ss), x = "bottomleft", col = colors,
		lty = 1:4)
dev.off()


# Try out a violin plot too!
# Maybe bisque isn't the best color for the curvy plots.
# For extra fun, log-transform the data (violins are made of wood)
#library(vioplot)
# c("GraphBIG","GraphMat","GAP")
#bfs_t_gb <- bfs_time[["Time"]][bfs_time[["Sys"]] == "GraphBIG"]
#bfs_t_gm <- bfs_time[["Time"]][bfs_time[["Sys"]] == "GraphMat"]
#bfs_t_gap <- bfs_time[["Time"]][bfs_time[["Sys"]] == "GAP"]
#vioplot(bfs_t_gb, bfs_t_gm, bfs_t_gap,
#		names=c("GraphBIG", "GraphMat", "GAP"),
#		col="bisque")
