# Generate some plots using the data parsed by ../../misc/parse-output.sh
# Make this section be the results from the optimal number of threads
library(ggplot2)
library(gridExtra)
library(scales)
#library(cowplot) # Gives plot_grid
prefix <- "results"
outdir <- "graphics_new"

# Doesn't quite work
# plot_value <- function(x, algo, metric, main_title, ylabel="Time (seconds)") {
# 	df <- subset(x, x$Algo == algo & x$Metric == metric,
# 			c("Sys","Time"))
# 	df$Sys <- factor(df$Sys, ordered=TRUE)
# 	df <- df[order(df$Sys),]
# 	boxplot(Time~Sys, df, ylab = ylabel,
# 			main = main_title, col=bpc, xaxt = "n", xlab = "")
# 	axis(1, labels=FALSE)
# 	ax_lab <- as.character(unique(df$Sys))
# 	text(x = seq_along(ax_lab), y = par("usr")[3]*1.1,
# 			labels = ax_lab, srt = 30, adj = c(0.95,0.95),
# 			xpd = TRUE, cex = 1.0)
# 	mtext(paste0("Scale = ",scale, ", nedges = ",
# 			prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
# }

avgs <- tabulate_data <- function(thr, dataset)
{
	filename <- paste0(prefix,"/","parsed-",dataset,"-",thr,".csv")
	x <- read.csv(filename, header = FALSE)
	colnames(x) <- c("Sys","Algo","Metric","Time")
	avgs <- aggregate(x$Time, list(x$Sys, x$Algo, x$Metric), mean)
	return(avgs)
}

base_breaks <- function(n = 5){
    function(x) {
        axisTicks(log10(range(x, na.rm = TRUE)), log = TRUE, n = n)
    }
}

compare_datasets <- function(all_avgs, dataset_list, metric = "Time")
{
	# If you just want a single algorithm, remove the "facet_wrap" line and use
	# avgs.m.a <- subset(all_avgs, all_avgs$Metric==metric & all_avgs$Algo==algo)
	avgs.m <- subset(all_avgs, all_avgs$Metric==metric)
	ylabel <- ifelse(metric == "Time", "Time (ms)", metric)
	p <- ggplot(avgs.m, aes(Dataset, Time * 1000, fill = Sys)) +
			geom_bar(stat = "identity", position = "dodge") +
			facet_wrap(~Algo, scales = "free") +
			scale_fill_brewer(palette="Accent") +
			ylab(ylabel) +
			# coord_trans(y="log10") + # Better than log(x*1000) but not supported
			scale_y_continuous(trans = "log10", breaks = base_breaks()) +
			# If your datasets are too long you can rename them
			scale_x_discrete(labels = c("dota","Patents")) +
			theme(axis.text.x = element_text(angle = 30, hjust = 1))
	outfn <- paste0(outdir,"/","compare-",metric,".pdf")
	message("Writing to ", outfn)
	pdf(outfn, width = 5, height = 5)
	print(p)
	dev.off()
}

###
# Realworld datasets
###
dataset_list <- c("cit-Patents", "dota-league")
thr <- 32 # Just start with one thread count
all_avgs <- data.frame()
for (dset in dataset_list) {
	avgs <- tabulate_data(thr, dset)
	all_avgs <- rbind(all_avgs, cbind(dset, avgs))
}
colnames(all_avgs) <- c("Dataset","Sys","Algo","Metric","Time")
compare_datasets(all_avgs, dataset_list)

###
# Power
###
# Just BFS for now.
# Read in the data
GRAPH500NRT <- 64 # Even though everyone else does 32.
scale <- 23
nedges <- nvertices * 2^scale
filename <- paste0(prefix,"/","parsed",scale,"-32-power.csv")
x <- read.csv(filename, header = FALSE)
colnames(x) <- c("Sys","Algo","Metric","Value")
bfs_cpu_pwr <- subset(x, x$Algo == "BFS" & x$Metric == "Average CPU Power (W)",
		c("Sys","Value"))
bfs_cpu_nrg <- subset(x, x$Algo == "BFS" & x$Metric == "Total CPU Energy (J)",
		c("Sys","Value"))
cpu_pwr_sleep <- subset(x,
		x$Sys == "Baseline" & x$Metric == "Average CPU Power (W)",
		c("Sys","Value"))
ram_pwr_sleep <- subset(x,
		x$Sys == "Baseline" & x$Metric == "Average DRAM Power (W)",
		c("Sys","Value"))
bfs_cpu_pwr$Sys <- factor(bfs_cpu_pwr$Sys)
bfs_cpu_nrg$Sys <- factor(bfs_cpu_nrg$Sys)

bfs_systems <- sort(unique(bfs_cpu_nrg$Sys))
bfs_cpu_nrg_per_root <- numeric(length(bfs_systems))
sleep_nrg_per_root <- numeric(length(bfs_systems))
bfs_time_per_root <- numeric(length(bfs_systems))
for (si in seq(length(bfs_systems))) {
	sys <- as.character(bfs_systems[si])
	one_sys <- subset(x,
			x$Algo=="BFS" & x$Metric=="Average CPU Power (W)" & x$Sys==sys,
			Value)
	sys_time <- subset(x,
			x$Algo=="BFS" & x$Metric=="RAPL Time (s)" & x$Sys == sys,
			Value)
	if (sys == "Graph500") {
		bfs_time_per_root[si] <- mean(sys_time$Value) / GRAPH500NRT
	} else {
		bfs_time_per_root[si] <- mean(sys_time$Value)
	}
	bfs_cpu_nrg_per_root[si] <- mean(one_sys$Value) * bfs_time_per_root[si]
	sleep_nrg_per_root[si] <- mean(cpu_pwr_sleep$Value) * bfs_time_per_root[si]
}

bfs_ram_pwr <- subset(x, x$Algo == "BFS" & x$Metric == "Average DRAM Power (W)",
		c("Sys","Value"))
bfs_ram_pwr$Sys <- factor(bfs_cpu_pwr$Sys)

# Print some stuff for the table
# We hope that sleeping uses less energy than running the BFS...
stopifnot(all(sleep_nrg_per_root < bfs_cpu_nrg_per_root))
intersperse <- function(vec, ele) { return(paste(vec, collapse = ele)) }
print(paste0(" & ", intersperse(bfs_systems, " & ")))
print(paste0("Time per Root (s) & ",
		intersperse(bfs_time_per_root, " & ")))
print(paste0("Average Power per Root (W) & ", intersperse(
		aggregate(bfs_cpu_pwr$Value, list(bfs_cpu_pwr$Sys), mean)[[2]],
		" & ")))
print(paste0("Average Energy per Root (J) & ",
		intersperse(bfs_cpu_nrg_per_root, " & ")))
print(paste0("Sleeping Energy (J) & ",
		intersperse(sleep_nrg_per_root, " & ")))
print(paste0("Increase over sleep & ",
		intersperse(bfs_cpu_nrg_per_root/sleep_nrg_per_root, " & ")))

###
# Generate the plots for a single problem size and multiple algorithms
###
nvertices <- 16
scale <- 22
nedges <- nvertices * 2^scale
bpc <- "cyan"
filename <- paste0(prefix,"/","parsed-kron-",scale,"-32.csv")
x <- read.csv(filename, header = FALSE)
colnames(x) <- c("Sys","Algo","Metric","Time")

bfs_time <- subset(x, x$Algo == "BFS" & x$Metric == "Time",
		c("Sys","Time"))
bfs_time$Sys <- factor(bfs_time$Sys, ordered=TRUE)
bfs_time <- bfs_time[order(bfs_time$Sys),]

bfs_dsc <- subset(x, x$Algo == "BFS" & x$Metric == "Data structure build",
		c("Sys","Time"))
bfs_dsc$Sys <- factor(bfs_dsc$Sys, ordered=TRUE)
bfs_dsc <- bfs_dsc[order(bfs_dsc$Sys),]

sssp_time <- subset(x, x$Algo == "SSSP" & x$Metric == "Time",
		c("Sys","Time"))
sssp_dsc <- subset(x, x$Algo == "SSSP" & x$Metric == "Data structure build",
		c("Sys","Time"))
sssp_time$Sys <- factor(sssp_time$Sys, ordered=TRUE)
sssp_time <- sssp_time[order(sssp_time$Sys),]
sssp_dsc$Sys <- factor(sssp_dsc$Sys, ordered=TRUE)
sssp_dsc <- sssp_dsc[order(sssp_dsc$Sys),]
# In the paper we compare range(sssp_time$Time) and range(bfs_time$Time)

pr_time <- subset(x, x$Algo == "PageRank" & x$Metric == "Time",
		c("Sys","Time"))
pr_dsc <- subset(x, x$Algo == "PageRank" & x$Metric == "Data structure build",
		c("Sys","Time"))
pr_iters <- subset(x, x$Algo == "PageRank" & x$Metric == "Iterations",
		c("Sys","Time"))
pr_time$Sys <- factor(pr_time$Sys, ordered=TRUE)
pr_time <- pr_time[order(pr_time$Sys),]
pr_dsc$Sys <- factor(pr_dsc$Sys, ordered=TRUE)
pr_dsc <- pr_dsc[order(pr_dsc$Sys),]

pdf(paste0(outdir,"/","bfs_time.pdf"), width = 5.2, height = 5.2)
boxplot(Time~Sys, bfs_time, ylab = "Time (seconds)",
		main = "BFS Time", col=bpc, xaxt = "n", xlab = "")
axis(1, labels=FALSE)
ax_lab <- as.character(unique(bfs_time$Sys))
text(x = seq_along(ax_lab),
		y = par("usr")[3]*1.1,
		labels = ax_lab,
		srt = 30,
		adj = c(0.95,0.95),
		xpd = TRUE,
		cex = 1.0)
mtext(paste0("Scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
dev.off()

pdf(paste0(outdir,"/","bfs_dsc.pdf"), width = 5.2, height = 5.2)
boxplot(Time~Sys, bfs_dsc, ylab = "Time (seconds)",
		main = "BFS Data Structure Construction", col=bpc, log = "y")
mtext(paste0("Scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
dev.off()

pdf(paste0(outdir,"/","sssp_time.pdf"), width = 5.5, height = 4.5)
bp <- boxplot(Time~Sys, sssp_time, ylab = "Time (seconds)",
		main = "SSSP Time", log = "y", col=bpc)
text(bp, par("usr")[3], labels = sssp_time[[1]], srt = 30,
		adj = c(0.95,0.95), xpd = TRUE, cex = 1.0)
mtext(paste0("Scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
dev.off()

pdf(paste0(outdir,"/","sssp_dsc.pdf"), width = 3.5, height = 4.5)
boxplot(Time~Sys, sssp_dsc, ylab = "Time (seconds)",
		main = "SSSP Data Structure\nConstruction", log = "y", col=bpc)
# mtext(paste0("Scale = ",scale), side = 3)
dev.off()

pdf(paste0(outdir,"/","pr_iters.pdf"), width = 4, height = 4)
pr_mean_iters <- aggregate(pr_iters$Time, list(pr_iters$Sys), mean)
pr_sys_order <- order(pr_mean_iters[[2]])
pr_mean_iters <- pr_mean_iters[pr_sys_order,]
bp <- barplot(pr_mean_iters[[2]], ylab = "Iterations",
		main = "PageRank Iterations", col=rainbow(length(pr_mean_iters[[1]])))
text(bp, par("usr")[3], labels = pr_mean_iters[[1]], srt = 30,
		adj = c(0.95,0.95), xpd = TRUE, cex = 1.0)
dev.off()

pdf(paste0(outdir,"/","pr_time.pdf"), width = 4, height = 4)
pr_sys_labels <- pr_mean_iters[[1]] # Get the order from iterations
pr_time$Sys <- factor(pr_time$Sys, pr_sys_labels, ordered = TRUE)
pr_time <- pr_time[order(pr_time$Sys),]
pr_sys <- levels(pr_time$Sys)
boxplot(Time~Sys, pr_time, ylab = "Time (seconds)",
		main = "PageRank Time", log = "y", col=bpc,
		xaxt = "n", xlab = "")
		#names.arg = pr_sys)
axis(1, labels = FALSE)
mtext(paste0("Scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
text(x = seq(pr_sys), y = par("usr")[3]+0.90,
		srt = 30, adj = c(1,2), xpd = TRUE,
		labels = pr_sys, cex = 1.0)
dev.off()


###
# Generate the plots for a single algorithm and multiple problem sizes
###
threadcnts <- c(1,2,4,8,16,32,64,72)
scale <- 22
nedges <- nvertices * 2^scale
measure_scale <- function(algo, scale) {
	# Read in and average the data for BFS for each thread
	# It is wasteful to reread the parsed*-1.csv but it simplifies the code
	x <- read.csv(paste0(prefix,"/","parsed-kron-",scale,"-1.csv"), header = FALSE)
	colnames(x) <- c("Sys","Algo","Metric","Time")
	x$Sys <- factor(x$Sys, ordered = TRUE)
	systems <- unique(subset(x$Sys, x$Algo == algo, c("Sys")))
	algo_time <- data.frame(
			matrix(ncol = length(threadcnts), nrow = length(systems)),
			row.names = systems)
	colnames(algo_time) <- threadcnts
	for (ti in seq(length(threadcnts))) {
		thread <- threadcnts[ti]
		Y <- read.csv(paste0(prefix,"/","parsed-kron-",scale,"-",thread,".csv"),
				header = FALSE)
		ti_time <- subset(Y, Y[[2]] == algo & Y[[3]] == "Time",
				c(V1,V4))
		algo_time[ti] <- aggregate(ti_time$V4, list(ti_time$V1), mean)[[2]]
	}
	return(algo_time)
}

bfs_scale <- measure_scale("BFS", scale)

colors <- rainbow(nrow(bfs_scale))
colors <- gsub("F", "C", colors) # You want it darker
colors <- gsub("CC$", "FF", colors) # But keep it opaque
bfs_ss <- bfs_scale
# Strong scaling for sequential is 1---we compute that last
for (ti in rev(seq(length(threadcnts)))) {
	bfs_ss[ti] <- bfs_ss[1] / (threadcnts[ti] * bfs_ss[ti])
}

# Plot the strong scalability for BFS
# Actually, this is called Parallel Efficiency!
pdf(paste0(outdir,"/","bfs_ss.pdf"), width = 7, height = 4)
systems <- rownames(bfs_ss)
plot(as.numeric(bfs_ss[1,]), xaxt = "n", type = "b", ylim = c(0,1),
		ylab = "", xlab = "Threads", col = colors[1],
		main = "BFS Parallel Efficiency", cex.main = 1.4, lty = 1, pch = 1, lwd = 3)
for (pli in seq(2,nrow(bfs_ss))) {
	lines(as.numeric(bfs_ss[pli,]), col = colors[pli], type = "b",
			lwd = 3, pch = pli, lty = pli) # XXX: lty may repeat after 8
}
# Linear strong scaling: T_n = T_1/n => T_1 / n*T_n = 1
lines(x = threadcnts, y = rep(1,length(threadcnts)), lwd = 2, col = "black")
axis(1, at = seq(length(threadcnts)), labels = threadcnts)
legend(legend = c("Linear", rownames(bfs_ss)), x = "topright",
		lty = c(1, 1:length(systems)), pch = c(NA_integer_, 1:length(systems)),
		box.lwd = 1, lwd = c(2, rep(3,length(systems))),
		col = c("#000000FF", colors),
		bg = "white")
mtext(paste0("Scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
mtext(expression(italic(over(T[1],n*T[n]))),
		side = 2, las = 1, xpd = NA, outer = TRUE, adj = -0.2)
dev.off()

# Plot the speedup for BFS
pdf(paste0(outdir,"/","bfs_speedup.pdf"), width = 7, height = 4)
bfs_spd <- data.frame(t(apply(bfs_ss, 1, function(x){x*threadcnts})))
colnames(bfs_spd) <- threadcnts
plot(as.numeric(bfs_spd[1,]), xaxt = "n", type = "b", ylim = c(1,18),
		ylab = "Speedup", xlab = "Threads", col = colors[1], log = "y",
		main = "BFS Speedup", cex.main=1.4, lty = 1, pch = 1, lwd = 3)
for (pli in seq(2,nrow(bfs_ss))) {
	lines(as.numeric(bfs_spd[pli,]), col = colors[pli], type = "b",
			lwd = 3, pch = pli, lty = pli) # XXX: lty may repeat after 8
}
lines(1:length(threadcnts), threadcnts, lwd = 1, col = "#000000FF")
axis(1, at = seq(length(threadcnts)), labels = threadcnts)
mtext(paste0("Scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
legend(legend = c("Linear", rownames(bfs_spd)), x = "topleft", bg = "white",
		col = c("#000000FF", colors), lwd = c(1,rep(3,length(systems))),
		lty = c(1:length(systems), 1), pch = c(NA_integer_, 1:length(systems)))
dev.off()

# This plot doesn't convey the data quite right...
# pdf(paste0(outdir,"/","bfs_cpu_energy.pdf"), width = 4.5, height = 4.5)
# bfs_cpu_nrg_mat <- matrix(
# 		c(sleep_nrg_per_root, bfs_cpu_nrg_per_root), # -sleep_nrg_per_root),
# 		nrow = 2, ncol = length(bfs_systems), byrow = TRUE)
# xcoords <- barplot(bfs_cpu_nrg_per_root, ylab = "Energy (Joules)",
# 		col=c("gold"),
# 		names.arg = bfs_systems)
# text(x = xcoords, y = bfs_cpu_nrg_per_root, label = bfs_time_per_root, pos = 3)
# title(main = "BFS CPU Energy Usage Per Root")
# mtext(paste0("Scale = ",scale), side = 3) # May want to remove subtitle later
# legend(legend = c("BFS Energy", "Sleeping Energy"), x = "topleft",
# 		fill = c("gold","orangered3"))
# dev.off()

# Make some plots
pdf(paste0(outdir,"/","bfs_cpu_power.pdf"), width = 5.2, height = 5.2)
boxplot(Value~Sys, bfs_cpu_pwr, ylab = "Average Power (Watts)",
		col="yellow", ylim=c(cpu_pwr_sleep$Value*0.9, max(bfs_cpu_pwr$Value)))
title(main = "CPU Average Power Consumption During BFS")
abline(mean(cpu_pwr_sleep$Value), 0, col = "orangered", lwd = 2)
mtext(paste0("Scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
legend(legend = c("sleep"), x = "bottomright", inset = c(0,0),
		lty = c(1), lwd = 2, col = "orangered", bg = "white")
dev.off()

pdf(paste0(outdir,"/","bfs_ram_power.pdf"), width = 5.2, height = 5.2)
boxplot(Value~Sys, bfs_ram_pwr, ylab = "Average Power (Watts)",
		col="yellow", ylim=c(ram_pwr_sleep$Value*0.9, max(bfs_ram_pwr$Value)))
title(main = "RAM Power Consumption During BFS",
		sub = paste0("Scale = ",scale)) # May want to remove subtitle later
abline(mean(ram_pwr_sleep$Value), 0, col = "orangered", lwd = 2)
mtext(paste0("Scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
legend(legend = c("sleep"), x = "bottomright", inset = c(0,0),
		lty = c(1), lwd = 2, col = "orangered", bg = "white")
dev.off()

###
# Part 6: Supplementary statistics used in the paper's prose.
###
sd(pr_time$Time[pr_time$Sys == "PowerGraph"]) /
		mean(pr_time$Time[pr_time$Sys == "PowerGraph"])
sd(sssp_time$Time[sssp_time$Sys == "PowerGraph"]) /
		mean(sssp_time$Time[sssp_time$Sys == "PowerGraph"])
sd(pr_time$Time[pr_time$Sys == "GraphBIG"]) /
		mean(pr_time$Time[pr_time$Sys == "GraphBIG"])
sd(sssp_time$Time[sssp_time$Sys == "GraphBIG"]) /
		mean(sssp_time$Time[sssp_time$Sys == "GraphBIG"])
sd(pr_time$Time[pr_time$Sys == "GAP"]) /
		mean(pr_time$Time[pr_time$Sys == "GAP"])
sd(sssp_time$Time[sssp_time$Sys == "GAP"]) /
		mean(sssp_time$Time[sssp_time$Sys == "GAP"])
sd(pr_time$Time[pr_time$Sys == "GraphMat"]) /
		mean(pr_time$Time[pr_time$Sys == "GraphMat"])
sd(sssp_time$Time[sssp_time$Sys == "GraphMat"]) /
		mean(sssp_time$Time[sssp_time$Sys == "GraphMat"])

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
#		col="bislevels


####
# Plot Machine Learning Results
###
DATA <- "Method,Algorithm,Rsquared,RMSD,NRMSD
R+N,SSSP,0.36,0.97,1.19
R+N,BFS,0.15,0.36,2.08
R+N,PR,0.19,48.72,1.59
R+N,TC,0.08,34.71,0.50
Ridge,SSSP,0.28,0.99,1.21
Ridge,BFS,0.09,0.38,2.23 
Ridge,PR,0.16,49.06,2.03 
Ridge,TC,0.08,35.61,0.54 
Norm,SSSP,0.36,0.98,1.36
Norm,BFS,0.10,0.43,2.71
Norm,PR,0.17,53.06,1.83
Norm,TC,0.03,32.61,0.46
None,SSSP,0.32,1.08,2.48
None,BFS,0.08,0.53,2.92
None,PR,0.14,55.02,2.05
None,TC,0.02,34.82,0.68
"
df <- read.csv(text=DATA, sep=",", header=TRUE)
p1 <- ggplot(df, aes(fill=Method, x=Algorithm, y=Rsquared)) +
		geom_bar(position="dodge", stat="identity") +
		ylab(bquote("R"^2)) +
		theme(axis.text.x=element_text(angle = 30, hjust = 1),
				axis.title.x=element_blank())
		#guides(fill=FALSE) # Don't put this since just having 1 guide messes up width
p2 <- ggplot(df, aes(fill=Method, x=Algorithm, y=RMSD)) +
		geom_bar(position="dodge", stat="identity") +
		theme(axis.text.x = element_text(angle = 30, hjust = 1),
				axis.title.x=element_blank())
p3 <- ggplot(df, aes(fill=Method, x=Algorithm, y=NRMSD)) +
		geom_bar(position="dodge", stat="identity") +
		theme(axis.text.x = element_text(angle = 30, hjust = 1),
				axis.title.x=element_blank())
outfn <- file.path(outdir, "lm.pdf")
pdf(outfn, width = 8, height = 4)
p <- grid.arrange(grobs = list(p1, p2, p3), nrow = 1, align = 'h',
		top = "Linear Regression Results", bottom = "Algorithm") +
	labs(title = "Linear Regression Results", x = "Algorithm")
print(p)
dev.off()

