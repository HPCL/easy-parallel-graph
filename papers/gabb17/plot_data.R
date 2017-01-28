# This is some bad bad bad R code.
# Might want to double check it.
scale <- 20
bpc <- "chartreuse"
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

pdf("graphics/bfs_time.pdf")
boxplot(Time~Sys, bfs_time, ylab = "Time (seconds)",
		main = "BFS Time", log = "y", col=bpc)
dev.off()

pdf("graphics/bfs_dsc.pdf")
boxplot(Time~Sys, bfs_dsc, ylab = "Time (seconds)",
		main = "BFS Data Structure Construction", col=bpc, log = "y")
dev.off()

pdf("graphics/sssp_time.pdf")
boxplot(Time~Sys, sssp_time, ylab = "Time (seconds)",
		main = "SSSP Time", log = "y", col=bpc)
dev.off()

pdf("graphics/sssp_dsc.pdf")
boxplot(Time~Sys, sssp_time, ylab = "Time (seconds)",
		main = "SSSP Data Structure Construction", log = "y", col=bpc)
dev.off()

pdf("graphics/pr_time.pdf")
barplot(pr_time$Time, ylab = "Time (seconds)",
		main = "PageRank Time", log = "y", col=bpc,
		names.arg=factor(pr_time$Sys))
dev.off()

pdf("graphics/pr_iters.pdf")
barplot(pr_iters$Time, ylab = "Time (seconds)",
		main = "PageRank Iterations", col="brown",
		names.arg=factor(pr_time$Sys))
dev.off()

# Try out a violin plot too!
# Maybe bisque isn't the best color for the curvy plots.
# For extra fun, log-transform the data (violins are made of wood)
library(vioplot)
# c("GraphBIG","GraphMat","GAP")
bfs_t_gb <- bfs_time[["Time"]][bfs_time[["Sys"]] == "GraphBIG"]
bfs_t_gm <- bfs_time[["Time"]][bfs_time[["Sys"]] == "GraphMat"]
bfs_t_gap <- bfs_time[["Time"]][bfs_time[["Sys"]] == "GAP"]
vioplot(bfs_t_gb, bfs_t_gm, bfs_t_gap,
		names=c("GraphBIG", "GraphMat", "GAP"),
		col="bisque")

# File reading not as useful
file_reading <- subset(x, x[[3]] == "File reading", select = c(V1,V4))
file_reading_times <- c(0,0,0)
file_reading_times[1] <- mean(file_reading[[2]][1:3])
file_reading_times[2] <- mean(file_reading[[2]][4:6])
file_reading_times[3] <- mean(file_reading[[2]][7:9])

# This doesn't work well
#barplot(file_reading_times,
#		names.arg = as.character(unique(file_reading[[1]])),
#		ylab="Time (seconds)",
#		log="y")
