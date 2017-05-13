library(ggplot2)

time_boxplot_with_batches <- function(filename, scale, ins_pct, cverts, num_threads) {
	x <- read.csv(filename, header = TRUE)
	# algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
	# execution_phase: All, rooting tree, first pass, insertion, deletion
	epv <- x$edges_per_vertex[1] # Assume the same throughout experiments
	if (scale > 99) {
		if (x$RMAT_type[1] == "com-lj.ungraph") {
			plot_title <- "Livejournal Dataset"
			nedges <- 34681189
			plot_subtitle <- paste0(nedges, " edges, ", scale, " vertices")
		} else {
			nedges <- epv * scale # Just an estimation
		}
		plotfilename <- paste0("plot-",x$RMAT_type[1],"_",ins_pct,"i_",cverts,"_10b.pdf")
	} else {
		nedges <- epv * 2^scale
		plotfilename <- paste0("plot",scale,"_",ins_pct,"i_",cverts,"_10b.pdf")
	}
	# Generate a figure
	salient_cols <- c("algorithm", "execution_phase", "value", "batch")
	method_time <- subset(x,
			x$scale==scale &
			x$edges_per_vertex == epv &
			x$changed_vertices==cverts &
			x$insertion_percent==ins_pct &
			x$threads == num_threads,
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
	box + theme(axis.text.x = element_text(angle = 90, hjust = 1))
	dev.off()
}

percent_insertions <- function(filename, scale_num, cvert,
		RMAT = "ER", num_threads = 72) {
	x <- read.csv(filename, header = TRUE)
	# algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
	# execution_phase: All, rooting tree, first pass, insertion, deletion
	# where rooting tree is only done for the first batch
	epv <- x$edges_per_vertex[1] # Assume the same throughout experiments
	nedges <- epv * 2^scale
	# Generate a figure
	salient_cols <- c("insertion_percent", "value")
	method_time <- subset(x,
			x$scale==scale_num &
			x$edges_per_vertex==epv &
			x$RMAT_type==RMAT &
			x$threads==num_threads &
			x$execution_phase=="All" &
			x$changed_vertices==cvert &
			x$algorithm=="MST",
			salient_cols)
	# method_time$value <- as.numeric(as.character(algo_time$Time)) # May not be necessary
	# Remove zero rows---they're invalid and don't work with the log plot
	# If some factors were coerced into NAs then there was some issue parsing
	#method_time <- algo_time[!algo_time$Time == 0.0, ]
	#method_time$algo_and_phase <- interaction(method_time$execution_phase, method_time$algorithm)
	
	pdf(paste0("insertion_pct_",scale_num,"_",cvert,"_time.pdf"), width = 2.5, height = 2.5)
	ggplot(aes(y = value, x = insertion_percent, group = insertion_percent),
			data = method_time) +
		ylab("Time (seconds)") +
		xlab("Insertion Percent") +
		scale_x_continuous(breaks = as.numeric(method_time$insertion_percent)) +
		geom_boxplot() +
		labs(title = "Update vs. Insertion %") +
		theme(axis.text.x = element_text(angle = 90, hjust = 1))
	dev.off()
}

measure_scalability <- function(filename, one_scale) {
    x <- read.csv(filename, header = TRUE)
	yy <- subset(x,
			x$scale == one_scale & x$changed_vertices == 5000 &
			x$insertion_percent == 75 & x$RMAT_type == "ER")
	threads <- unique(yy$threads)
	# TEST
	# subset(x,
	# 		x$scale == one_scale & x$changed_vertices == 5000 & x$insertion_percent == 75
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

plot_strong_scaling <- function(scaling_data, scale) {
	colors <- rainbow(nrow(scaling_data))
	colors <- gsub("F", "C", colors) # You want it darker
	colors <- gsub("CC$", "FF", colors) # But keep it opaque
	threadcnts <- as.numeric(colnames(scaling_data))
    systems <- rownames(scaling_data)

	pdf(paste0(scale,"_time.pdf"), width = 7, height = 4)
	plot(as.numeric(scaling_data[1,]), xaxt = "n", type = "b",
			ylab = "Time (seconds)", xlab = "Threads", col = colors[1],
			main = paste0("Runtime for MST and Galois at Scale 23"),
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
	mtext(paste0("Scale = ",scale," nedges = ",8 * 2^scale), side = 3)
	#mtext(expression(italic(over(T[1],n*T[n]))),
	#			  side = 2, las = 1, xpd = NA, outer = TRUE, adj = -0.2)
	dev.off()
}

time_boxplot_with_batches("parsed-238_ER+B_75i_10000_64t_10batches.csv",
						  23, 10000, 75, 64)
# Partial means only 3--4 experiments were run.
ss22 <- measure_scalability("parsed-20-23-partial.txt", 22)
ss23 <- measure_scalability("parsed-20-23-partial.txt", 23)
plot_strong_scaling(ss23) # These results are not nice
percent_insertions("parsed-20-23-partial.txt",
				   23, 5000, RMAT = "ER", num_threads = 72)

#DATASETS=( com-lj.ungraph )
#REAL_VERTICES=( 4036538 )
#REAL_EDGES=( 34681189 )
#THREADS="1 2 4 8 16 32 48 64 72"
#NUM_BATCHES=10
#NUM_TRIALS=8
#THREADS="64"
#CHANGED_VERTICES="10000"
#INS_PCTAGES="75"
time_boxplot_with_batches("parsed-lj_75i_10000.txt", 4036538, 75, 10000, 64)

