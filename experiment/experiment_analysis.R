# Given the results from parse-output.sh, generate some plots of the data
# TODO: Change 16 to nvertices
usage <- "usage: Rscript experiment_analysis.R <config_file>"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
	stop(usage)
}
# Default arguments. See config_template.R for an explanation
prefix <- "./output/" # The default.
coalesce <- FALSE

# source sets scale and threads
source(args[1]) # This is a security vulnerability... just be careful

# Assuming default edgefactor of 16
stopifnot(length(scale) == 1) # Multiple scales in one go not supported yet

###
# Define some functions
###
# given a scale, algorithm, (BFS, SSSP, or PageRank), a number of threads,
# and a timing metric where timing_metric %in%
# {"Time", "File reading", "Iterations", "Data structure build"},
# generate a pdf boxplot, one box per System, of the runtimes.
time_boxplot <- function(scale, thr, algo, timing_metric = "Time") {
	out_fn <- paste0("graphics/", algo, "_", gsub(" ", "_", timing_metric),
			"_", scale, "-", thr, "t.pdf")
	message("Writing to ", out_fn)
	nedges <- 16 * 2^scale
	in_fn <- paste0(prefix,"parsed-","kron-",scale,"-",thr,".csv")
	x <- read.csv(in_fn, header = FALSE)
	colnames(x) <- c("Sys","Algo","Metric","Time")
	# Generate a figure
	algo_time <- subset(x, x$Algo == algo & x$Metric == timing_metric,
			c("Sys","Time"))
	stopifnot(nrow(algo_time) > 0)
	algo_time$Time <- as.numeric(as.character(algo_time$Time))
	# Remove zero rows---they're invalid and don't work with the log plot
	# If some factors were coerced into NAs then there was some issue parsing
	algo_time <- algo_time[!algo_time$Time == 0.0, ]
	pdf(out_fn, width = 5.2, height = 5.2)
	ylabel <- timing_metric
	if (timing_metric == "Time") {
		ylabel <- paste(ylabel, "(seconds)")
	}
	boxplot(Time~Sys, data = algo_time, ylab = ylabel,
			main = paste(algo, "Time on", thr, "Threads"),
			log = "y", col="cyan")
	mtext(paste0("scale = ",scale, " nedges = ",nedges), side = 3)
	dev.off()
}

# Generate the plots for a single algorithm and multiple problem sizes
measure_scale <- function(scale, threads, algo) {
    # Read in and average the data for BFS for each thread
    # It is wasteful to reread the parsed*-1t.csv but it simplifies the code
	in_fn <- paste0(prefix,"parsed-","kron-",scale,"-1.csv")
    x <- read.csv(in_fn, header = FALSE)
    colnames(x) <- c("Sys","Algo","Metric","Time")
    x$Sys <- factor(x$Sys, ordered = TRUE)
    systems <- levels(subset(x$Sys, x$Algo == algo, c("Sys")))
    algo_time <- data.frame(
            matrix(ncol = length(threads), nrow = length(systems)),
            row.names = systems)
    colnames(algo_time) <- threads
    for (ti in seq(length(threads))) {
		# V1 -> Sys, V4 -> Time
        thr <- threads[ti]
		in_fn <- paste0(prefix,"parsed-kron-",scale,"-",thr,".csv")
        Y <- read.csv(in_fn, header = FALSE)
        ti_time <- subset(Y, Y[[2]] == algo & Y[[3]] == "Time",
                c(V1,V4))
		ti_time$V4 <- as.numeric(as.character(ti_time$V4))
		one_ti <- aggregate(ti_time$V4, list(ti_time$V1), mean)
		for (sysi in seq(length(one_ti[[1]]))) {
			algo_time[rownames(algo_time) == one_ti[sysi,1], ti] <- one_ti[sysi,2]
		}
    }
    return(algo_time)
}

# scaling data: The data.frame returned from measure_scale
plot_strong_scaling <- function(scaling_data, scale, threadcnts, algo) {
	# Strong scaling for sequential is 1---we compute that last
	alg_ss <- scaling_data
	for (ti in rev(seq(length(threads)))) {
		alg_ss[ti] <- scaling_data[1] / (threads[ti] * scaling_data[ti])
	}
	systems <- rownames(alg_ss)
	colors <- rainbow(nrow(alg_ss))
	colors <- gsub("F", "C", colors) # You want it darker
	colors <- gsub("CC$", "FF", colors) # But keep it opaque
	out_fn <- paste0("graphics/",algo,"_ss",scale,".pdf")
	message("Writing to ", out_fn)
	pdf(out_fn, width = 7, height = 4)
	plot(as.numeric(alg_ss[1,]), xaxt = "n", type = "b", ylim = c(0,1),
			ylab = "", xlab = "Threads", col = colors[1],
			main = paste0(algo, " Strong Scaling"),
			cex.main = 1.4, lty = 1, pch = 1, lwd = 3)
	for (pli in seq(2,nrow(alg_ss))) {
			lines(as.numeric(alg_ss[pli,]), col = colors[pli], type = "b",
					lwd = 3, pch = pli, lty = pli) # XXX: lty may repeat after 8
	}
	# Linear strong scaling: T_n = T_1/n => T_1 / n*T_n = 1
	lines(x = threadcnts, y = rep(1,length(threadcnts)), lwd = 2, col = "black")
	axis(1, at = seq(length(threadcnts)), labels = threadcnts)
	legend(legend = c("Linear", rownames(alg_ss)), x = "topright",
			lty = c(1, 1:length(systems)),
			pch = c(NA_integer_, 1:length(systems)),
			box.lwd = 1, lwd = c(2, rep(3,length(systems))),
			col = c("#000000FF", colors),
			bg = "white")
	mtext(paste0("Scale = ",scale," nedges = ",16 * 2^scale), side = 3)
	mtext(expression(italic(over(T[1],n*T[n]))),
				  side = 2, las = 1, xpd = NA, outer = TRUE, adj = -0.2)
	dev.off()
	return(alg_ss)
}

plot_speedup <- function(strong_scaling, scale, threadcnts, algo)
{
	spd <- data.frame(t(apply(strong_scaling, 1, function(x){x*threadcnts})))
	colnames(spd) <- threadcnts
	systems <- rownames(strong_scaling)
	colors <- rainbow(nrow(strong_scaling))
	colors <- gsub("F", "C", colors) # You want it darker
	colors <- gsub("CC$", "FF", colors) # But keep it opaque
	out_fn <- paste0("graphics/",algo,"_speedup",scale,".pdf")
	message("Writing to ", out_fn)
	pdf(out_fn, width = 7, height = 4)
	plot(as.numeric(spd[1,]), xaxt = "n", type = "b", ylim = c(1,10),
			ylab = "Speedup", xlab = "Threads", col = colors[1], log = "y",
			main = paste(algo,"Speedup"), cex.main=1.4, lty = 1, pch = 1, lwd = 3)
	for (pli in seq(2,nrow(strong_scaling))) {
		lines(as.numeric(spd[pli,]), col = colors[pli], type = "b",
				lwd = 3, pch = pli, lty = pli) # XXX: lty may repeat after 8
	}
	lines(1:length(threadcnts), threadcnts, lwd = 1, col = "#000000FF")
	axis(1, at = seq(length(threadcnts)), labels = threadcnts)
	mtext(paste("Scale =", scale), side = 3)
	legend(legend = c("Linear", rownames(spd)), x = "topleft", bg = "white",
			col = c("#000000FF", colors), lwd = c(1,rep(3,length(systems))),
			lty = c(1:length(systems), 1), pch = c(NA_integer_, 1:length(systems)))
	dev.off()
	return(spd)
}

###
# Generate some figures for a single graph size
###
thr <- focus_thread
scl <- focus_scale
# Possiblities: BFS, SSSP, PageRank, TC
bfs_scale <- measure_scale(scl, threads, "BFS")
result_pkgs <- complete.cases(bfs_scale)
if (!all(result_pkgs )) {
	message("Removing ",
			paste(rownames(bfs_scale)[!result_pkgs ], collapse=", "),
			" from results")
}
bfs_scale <- bfs_scale[result_pkgs, ]
bfs_ss <- plot_strong_scaling(bfs_scale, scl, threads, "BFS")
bfs_spd <- plot_speedup(bfs_ss, scl, threads, "BFS")

message("Saving boxplots of various measurements. These may need to be edited")
time_boxplot(scl, thr, "BFS", timing_metric = "Time")
time_boxplot(scl, thr, "BFS", timing_metric = "Data structure build")
time_boxplot(scl, thr, "SSSP", timing_metric = "Time")
time_boxplot(scl, thr, "PageRank", timing_metric = "Time")
time_boxplot(scl, thr, "PageRank", timing_metric = "Iterations")
# time_boxplot(scl, thr, "TC", timing_metric = "Time")
# time_boxplot(scl, thr, "TC", timing_metric = "Triangles")

###
# Dump performance data in a csv
###
# TODO: Add in parallel efficiency
header <- c("package", "algorithm", "nvertices", "nedges", "nthreads",
            "runtime")
# XXX: This isn't big enough so it's not preallocated, but it's not too slow.
perf_df <- data.frame(
		matrix(nrow = length(threads) * length(algos) * length(kron_scales),
		       ncol = length(header)))
colnames(perf_df) <- header
if (coalesce == TRUE) {
	ri = 1
	for (scl in kron_scales) {
		for (thr in threads) {
			# nedges \approx 16 * 2^scale
			in_fn <- paste0(prefix,"parsed-","kron-",scl,"-",thr,".csv")
			if (!file.exists(in_fn)) {
				next
			}
			x <- read.csv(in_fn, header = FALSE)
			# TODO: Get the actual number of edges and vertices
			# We collect just the mean runtime from the parsed results
			avg_x <- aggregate(x$V4, list(x$V1, x$V2, x$V3), FUN = mean)
			combo <- avg_x[avg_x[[3]] == "Time", c(1,2,4) ]
			combo <- cbind(combo, 2^scl, 16 * 2^scl, thr)
			# This is the actual order of the parsed data
			colnames(combo) <- c("package", "algorithm", "runtime",
			                     "nvertices", "nedges", "nthreads")
			combo <- combo[ ,header] # it must be reordered
			# Note: This converts factors to integers.
			# TODO: May want to also store a mapping from integers -> factors
			perf_df[ri:(ri+nrow(combo)-1), ] <- combo
			ri <- ri + nrow(combo)
		}
	}
	message("Writing all experimental data to ", coalesce_filename)
	write.csv(perf_df, file = coalesce_filename,
	          quote = FALSE, row.names = FALSE)
}

