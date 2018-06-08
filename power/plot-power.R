# Parse and generate tables for power, energy, etc.
# Example filename:
# ~/easy-parallel-graph/experiment/oldoutput/parsed22-32-power.csv
usage <- "usage: Rscript plot-power.R <parsed-power-fn>"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
	stop(usage)
}
fn <- args[1]
thr <- 32
algo <- "BFS"
scale <- 22
timing_metric <- "Average CPU Power (W)"
main_title <- "CPU Average Power Consumption During BFS"

time_boxplot <- function(in_fn, scale, thr, algo, timing_metric = "Time", nvertices=16, main_title="") {
	out_fn <- paste0(algo, "_", gsub(" ", "_", timing_metric),
			"_", scale, "-", thr, "t.pdf")
	message("Writing to ", out_fn)
	nedges <- nvertices * 2^scale
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
	algo_time <- algo_time[!algo_time$Sys == "Baseline", ]
	algo_time <- droplevels(algo_time)
	pdf(out_fn, width = 5.2, height = 5.2)
	ylabel <- timing_metric
	if (timing_metric == "Time") {
		ylabel <- paste(ylabel, "(seconds)")
	}
	if (main_title == "") {
		main_title <- paste(algo, "Time on", thr, "Threads")
	}
	baseline <- x[x$Sys=="Baseline" & x$Metric == timing_metric,]$Time
	boxplot(Time~Sys, data = algo_time, ylab = ylabel,
			main = main_title,
			ylim = c(baseline*0.9, max(algo_time$Time)),
			log = "", col="yellow")
	abline(baseline, 0, col="orangered", lwd=2)
	mtext(paste0("scale = ",scale, ", nedges = ",prettyNum(nedges,big.mark=",",scientific=FALSE)), side = 3)
	legend(legend = c("sleep"), x = "bottomright", inset = c(0,0),
		   		lty = c(1), lwd = 2, col = "orangered", bg = "white")
	dev.off()
}

time_boxplot(fn, scale, thr, algo, timing_metric=timing_metric, main_title=main_title)
