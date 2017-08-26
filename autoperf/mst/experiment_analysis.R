library(ggplot2)
# e.g.
# Rscript experiment_analysis.R cc-experiment/parsed-power-aggregate.txt 24 100 1000000 32 G
# Alternatively you could interactively call within R
# commandArgs <- function(trailingOnly=TRUE) c("cc-experiment/parsed-power-aggregate.txt","24","100","1000000","32","G")
# source("experiment_analysis.R")
usage <- "usage: Rscript experiment_analysis.R <filename> <scale> <insertion_%> <changed_vertices> <num_threads> <rmat_type>"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 6) {
	stop(usage)
}
filename <- args[1]
scale_num <- as.numeric(args[2])
ins_pct <- as.numeric(args[3])
cverts <- as.numeric(args[4])
num_threads <- as.numeric(args[5])
rmat_type <- args[6]
num_batches <- 1
epv <- 8
if (num_batches <= 1) {
	with_batches <- FALSE
} else {
	with_batches <- TRUE
}

# This takes a filename, reads it in, then filters it down by the parameters
# and adds a column for their interations.
# E.g. Galois.All, MST.insertion, MST.rooting tree, etc.
# Expects the header to be
# algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
get_method_time <- function(filename, scale_num, ins_pct, cverts, num_threads,
							rmat_type = "ER", measurement_type = "Time (s)")
{
	x <- read.csv(filename, header = TRUE)
	epv <- x$edges_per_vertex[1] # Assume the same throughout experiments
	salient_cols <- c("algorithm", "execution_phase", "batch", "measurement", "value")
	method_time <- subset(x,
			x$scale==scale_num &
			x$RMAT_type==rmat_type &
			x$edges_per_vertex==epv &
			x$changed_vertices==cverts &
			x$insertion_percent==ins_pct &
			x$threads==num_threads &
			x$measurement==measurement_type,
			salient_cols)
	# This is necessary if the data is noisy; then $value becomes a factor
	# method_time$value <- as.numeric(as.character(method_time$value))
	# Remove zero rows---they're invalid and don't work with the log plot
	# If some factors were coerced into NAs then there was some issue parsing
	#method_time <- algo_time[!algo_time$Time == 0.0, ]
	method_time$algo_and_phase <-
			interaction(method_time$execution_phase, method_time$algorithm)
	return(method_time)
}

time_boxplot_with_batches <- function(filename, scale_num, ins_pct, cverts, num_threads)
{
	x <- read.csv(filename, header = TRUE)
	# algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
	# execution_phase: All, rooting tree, first pass, insertion, deletion
	epv <- x$edges_per_vertex[1] # Assume the same throughout experiments
	if (scale_num > 99) {
		if (x$RMAT_type[1] == "com-lj.ungraph") {
			plot_title <- "Livejournal Dataset"
			nedges <- 34681189
			plot_subtitle <- paste0(nedges, " edges, ", scale_num, " vertices")
		} else {
			nedges <- epv * scale_num # Just an estimation
		}
		plotfilename <- paste0("plot-",x$RMAT_type[1],"_",ins_pct,"i_",cverts,"_10b.pdf")
	} else {
		nedges <- epv * 2^scale_num
		plotfilename <- paste0("plot",scale_num,"_",ins_pct,"i_",cverts,"_10b.pdf")
		plot_title <- paste0("RMAT with Scale ",scale_num)
		plot_subtitle <- paste0(nedges, "edges, ", 2^scale_num, " vertices")
	}
	# Generate a figure
	salient_cols <- c("algorithm", "execution_phase", "value", "batch")
	method_time <- subset(x,
			x$scale==scale_num &
			x$edges_per_vertex==epv &
			x$changed_vertices==cverts &
			x$insertion_percent==ins_pct &
			x$threads==num_threads &
			x$measurement=="Time (s)",
			salient_cols)
	# method_time$value <- as.numeric(as.character(algo_time$Time)) # May not be necessary
	# Remove zero rows---they're invalid and don't work with the log plot
	# If some factors were coerced into NAs then there was some issue parsing
	#method_time <- algo_time[!algo_time$Time == 0.0, ]
	method_time$algo_and_phase <- interaction(method_time$execution_phase, method_time$algorithm)
	
	pdf(plotfilename, width = 3.3, height = 3.3)
	box <- ggplot(aes(y = value, x = algo_and_phase), data = method_time) +
		ylab("Time (seconds)") +
		xlab("Execution Phase.Algorithm") +
		geom_boxplot() +
		labs(title = plot_title, subtitle = plot_subtitle)
	box + theme(axis.text.x = element_text(angle = 30, hjust = 1))
	dev.off()
}

percent_insertions <- function(filename, scale_num, cverts,
		RMAT = "ER", num_threads = 72)
{
	x <- read.csv(filename, header = TRUE)
	# algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
	# execution_phase: All, rooting tree, first pass, insertion, deletion
	# where rooting tree is only done for the first batch
	epv <- x$edges_per_vertex[1] # Assume the same throughout experiments
	nedges <- epv * 2^scale_num
	# Generate a figure
	salient_cols <- c("insertion_percent", "value")
	method_time <- subset(x,
			x$scale==scale_num &
			x$edges_per_vertex==epv &
			x$RMAT_type==RMAT &
			x$threads==num_threads &
			x$execution_phase=="All" &
			x$changed_vertices==cverts &
			x$algorithm=="MST",
			salient_cols)
	# method_time$value <- as.numeric(as.character(algo_time$Time)) # May not be necessary
	# Remove zero rows---they're invalid and don't work with the log plot
	# If some factors were coerced into NAs then there was some issue parsing
	#method_time <- algo_time[!algo_time$Time == 0.0, ]
	#method_time$algo_and_phase <- interaction(method_time$execution_phase, method_time$algorithm)
	
	p <- ggplot(data = method_time,
				aes(y = value, x = insertion_percent, group = insertion_percent)) +
		ylab("Time (seconds)") +
		xlab("Insertion Percent") +
		scale_x_continuous(breaks = as.numeric(method_time$insertion_percent)) +
		geom_boxplot() +
		labs(title = "Update vs. Insertion %") +
		theme(axis.text.x = element_text(angle = 90, hjust = 1))
	pdf(paste0("insertion_pct_",scale_num,"_",cverts,"_time.pdf"), width = 2.5, height = 2.5)
	p
	dev.off()
}

measure_scalability <- function(filename, scale_num,
		measurement_type = "Total CPU Energy (J)")
{
    x <- read.csv(filename, header = TRUE)
	yy <- subset(x,
			x$scale == scale_num & x$changed_vertices == cverts &
			x$insertion_percent == ins_pct & x$RMAT_type == rmat_type &
			x$measurement == measurement_type)
	threads <- unique(yy$threads)
	# TEST
	# subset(x,
	# 		x$scale == scale_num & x$changed_vertices == 5000 & x$insertion_percent == 75
	# 		& x$RMAT_type == "ER" & x$execution_phase == "All",
	# 		c("algorithm", "execution_phase", "threads", "value"))
    systems <- levels(subset(yy$algorithm, yy$execution_phase == "All", c("algorithm")))
    algo_time <- data.frame(
            matrix(ncol = length(threads), nrow = length(systems)),
            row.names = systems)
    colnames(algo_time) <- threads
    for (ti in seq(length(threads))) {
        thr <- threads[ti]
        thr_time <- subset(yy,
				yy$threads == thr & yy$execution_phase == "All")
		one_time <- aggregate(thr_time$value, list(thr_time$algorithm), mean)
		for (sysi in seq(length(one_time[[1]]))) { # For each algorithm
			algo_time[rownames(algo_time) == one_time[sysi,1], ti] <- one_time[sysi,2]
		}
    }
    return(algo_time)
}

# Plots just runtime
plot_strong_scaling <- function(scaling_data, scale_num,
		measurement_type = "Total CPU Energy (J)")
{
	colors <- rainbow(nrow(scaling_data))
	colors <- gsub("F", "C", colors) # You want it darker
	colors <- gsub("CC$", "FF", colors) # But keep it opaque
	threadcnts <- as.numeric(colnames(scaling_data))
    systems <- rownames(scaling_data)
	log_axes <- ifelse(max(scaling_data) / min(scaling_data) > 100, "y", "")

	out_fn <- paste0(scale_num,"_scaling.pdf")
	message("Writing to ", out_fn)
	pdf(out_fn, width = 7, height = 4)
	plot(as.numeric(scaling_data[1,]), xaxt = "n", type = "b",
			log = log_axes,
			ylim = c(min(scaling_data)*0.9,
					max(scaling_data)*ifelse(log_axes=="y", 2, 1.1)),
			ylab = measurement_type, xlab = "Threads", col = colors[1],
			main = paste0("Runtime for CC and Galois at Scale ", scale_num),
			cex.main = 1.4, lty = 1, pch = 1, lwd = 3)
	for (pli in seq(2,nrow(scaling_data))) {
			lines(as.numeric(scaling_data[pli,]), col = colors[pli], type = "b",
					lwd = 3, pch = pli, lty = pli) # XXX: lty may repeat after 8
	}
	axis(1, at = seq(length(threadcnts)), labels = threadcnts)
	legend(legend = rownames(scaling_data), x = "topright",
			lty = c(1:length(systems)),
			pch = c(1:length(systems)),
			box.lwd = 1, lwd = c(rep(3,length(systems))),
			col = c(colors),
			bg = "white")
	mtext(paste0("Scale = ",scale_num," nedges = ",epv * 2^scale_num), side = 3)
	dev.off()
}

plot_parallel_efficiency <- function(scaling_data, scale_num)
{
	threadcnts <- as.numeric(colnames(scaling_data))
	alg_ss <- scaling_data
	for (ti in rev(seq(length(threadcnts)))) {
		alg_ss[ti] <- scaling_data[1] / (threadcnts[ti] * scaling_data[ti])
	}
	systems <- rownames(alg_ss)
	colors <- rainbow(nrow(alg_ss))
	colors <- gsub("F", "C", colors) # You want it darker
	colors <- gsub("CC$", "FF", colors) # But keep it opaque
	out_fn <- paste0(scale_num,"_parallel_eff.pdf")
	message("Writing to ", out_fn)
	pdf(out_fn, width = 7, height = 4)
	plot(as.numeric(alg_ss[1,]), xaxt = "n", type = "b",
			ylim = c(0, ifelse(max(alg_ss) > 1, max(alg_ss), 1)),
			ylab = "", xlab = "Threads", col = colors[1],
			main = paste0("Parallel Efficiency"),
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
	mtext(paste0("Scale = ",scale_num," nedges = ",epv * 2^scale_num), side = 3)
	mtext(expression(italic(over(T[1],n*T[n]))),
				  side = 2, las = 1, xpd = NA, outer = TRUE, adj = -0.2)
	dev.off()
	return(alg_ss)
}

# Can also not do power if you pick "Time (s)". Generates a box
# for each execution phase:
# execution_phase: All, rooting tree, first pass, insertion, deletion
# possible values for measurement_type:
# "Time (s)" "Total CPU Energy (J)" "Average CPU Power (W)" "RAPL Time (s)"
power_boxplot <- function(
		filename, scale_num, ins_pct, cverts, num_threads, rmat_type,
		measurement_type = "Total CPU Energy (J)",
		with_batches = FALSE)
{
	x <- read.csv(filename, header = TRUE)
	# algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
	epv <- x$edges_per_vertex[1] # Assume the same throughout experiments
	nedges <- epv * 2^scale_num
	if (with_batches) {
		salient_cols <- c("algorithm", "execution_phase", "batch", "measurement", "value")
	} else {
		salient_cols <- c("algorithm", "execution_phase", "measurement", "value")
	}
	method_time <- subset(x,
			x$scale==scale_num &
			x$RMAT_type==rmat_type &
			x$edges_per_vertex==epv &
			x$changed_vertices==cverts &
			x$insertion_percent==ins_pct &
			x$threads==num_threads &
			x$measurement==measurement_type,
			salient_cols)
	if (nrow(method_time) == 0) {
		stop("No experiments satisfy these conditions")
	}
	# This is necessary if the data is noisy; then $value becomes a factor
	# method_time$value <- as.numeric(as.character(method_time$value))
	# Remove zero rows---they're invalid and don't work with the log plot
	# If some factors were coerced into NAs then there was some issue parsing
	#method_time <- algo_time[!algo_time$Time == 0.0, ]
	method_time$algo_and_phase <- interaction(method_time$execution_phase, method_time$algorithm)
	
	if (measurement_type == "Time (s)") {
		plot_title <- paste0("Time with RMAT Scale ", scale_num)
	} else if (measurement_type == "Average CPU Power (W)") {
		plot_title <- paste0("Power Usage with RMAT Scale ", scale_num)
	} else if (measurement_type == "Total CPU Energy (J)") {
		plot_title <- paste0("Power Usage with RMAT Scale ", scale_num)
	} else {
		stop("Unrecognized measurement type '", measurement_type, "'")
	}
	plot_subtitle <- paste(2^scale_num, "vertices", epv, "edges per vertex")
	# Generate a figure
	plotfilename <- paste0("plot-",
			measurement_type,"-",scale_num,epv,"_",ins_pct,"i_",
			cverts,"c_",num_threads,"t_",rmat_type,".pdf")
	pdf(plotfilename, width = 3.7, height = 3.7)
	box <- ggplot(aes(y = value, x = algo_and_phase), data = method_time) +
		ylab(measurement_type) +
		xlab("Execution Phase.Algorithm") +
		geom_boxplot() +
		labs(title = plot_title, subtitle = plot_subtitle) +
		theme(axis.text.x = element_text(angle = 90, hjust = 1))
	print(box)
	dev.off()
	message("plot written to ", plotfilename)
}

# "Time (s)" "Total CPU Energy (J)" "Average CPU Power (W)" "RAPL Time (s)"
power_boxplot(
		filename, scale_num, ins_pct, cverts, num_threads, rmat_type,
		measurement_type = "Total CPU Energy (J)",
		with_batches = FALSE)

ss_time <- measure_scalability(filename, scale_num,
		measurement_type = "Time (s)")
plot_strong_scaling(ss_time, scale_num, measurement_type = "Time (s)")
ss <- plot_parallel_efficiency(ss_time, scale_num)

