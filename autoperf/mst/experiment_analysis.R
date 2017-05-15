library(ggplot2)

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
			x$scale==scale &
			x$RMAT_type==rmat &
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

percent_insertions <- function(filename, scale_num, cvert,
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
			x$changed_vertices==cvert &
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
	pdf(paste0("insertion_pct_",scale_num,"_",cvert,"_time.pdf"), width = 2.5, height = 2.5)
	p
	dev.off()
}

measure_scalability <- function(filename, one_scale)
{
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

plot_strong_scaling <- function(scaling_data, scale)
{
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

# Can also not do power if you pick "Time (s)". Generates a box
# for each execution phase:
# execution_phase: All, rooting tree, first pass, insertion, deletion
# possible values for measurement_type:
# "Time (s)" "Total CPU Energy (J)" "Average CPU Power (W)" "RAPL Time (s)"
power_boxplot_with_batches <- function(
		filename, scale_num, ins_pct, cverts, num_threads,
		measurement_type = "Total CPU Energy (J)", rmat = "ER")
{
	x <- read.csv(filename, header = TRUE)
	# algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
	epv <- x$edges_per_vertex[1] # Assume the same throughout experiments
	plotfilename <- paste0("plot-",measurement_type,"-",scale_num,epv,"_",ins_pct,"i_",cverts,"_10b.pdf")
	nedges <- epv * 2^scale_num
	salient_cols <- c("algorithm", "execution_phase", "batch", "measurement", "value")
	method_time <- subset(x,
			x$scale==scale &
			x$RMAT_type==rmat &
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
	method_time$algo_and_phase <- interaction(method_time$execution_phase, method_time$algorithm)
	
	if (measurement_type == "Time (s)") {
		plot_title <- paste0("Time with RMAT Scale ", scale)
	} else if (measurement_type == "Average CPU Power (W)") {
		plot_title <- paste0("Power Usage with RMAT Scale ", scale)
	} else if (measurement_type == "Average CPU Energy (J)") {
		plot_title <- paste0("Power Usage with RMAT Scale ", scale)
	}
	plot_subtitle <- paste(2^scale_num, "vertices", epv, "edges per vertex")
	# Generate a figure
	pdf(plotfilename, width = 3.3, height = 3.3)
	box <- ggplot(aes(y = value, x = algo_and_phase), data = method_time) +
		ylab(measurement_type) +
		xlab("Execution Phase.Algorithm") +
		geom_boxplot() +
		labs(title = plot_title, subtitle = plot_subtitle)
	box + theme(axis.text.x = element_text(angle = 90, hjust = 1))
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
time_boxplot_with_batches("parsed-lj_75i_10000.csv", 4036538, 75, 10000, 64)

#sudo ./run --power experiment
#EPV=32 # or 8
#SCALES=23
#NUM_BATCHES=10
#NUM_TRIALS=8
#THREADS="72"
#RT_TYPES="ER"
#CHANGED_VERTICES="10000"
#INS_PCTAGES="75"
num_batches <- 10
scale_num <- 23
ins_pct <- 75
cverts <- 10000
num_threads <- 72
filename <- "parsed-power-2332_ER_75i_10000_72t.csv"
power_boxplot_with_batches(filename, scale_num, ins_pct, cverts, num_threads,
						   measurement_type = "Time (s)")
filename <- "parsed-power-238_ER_75i_10000_72t.csv"
power_boxplot_with_batches(filename, scale_num, ins_pct, cverts, num_threads,
						   measurement_type = "Time (s)")

# "Time (s)" "Total CPU Energy (J)" "Average CPU Power (W)" "RAPL Time (s)"
# Time
method_time32 <- get_method_time("parsed-power-2332_ER_75i_10000_72t.csv",
							   scale_num, ins_pct, cverts, num_threads)
avg_times32 <- aggregate(method_time32$value, list(method_time32$algo_and_phase), mean)
method_time8 <- get_method_time("parsed-power-238_ER_75i_10000_72t.csv",
							   scale_num, ins_pct, cverts, num_threads)
avg_times8 <- aggregate(method_time8$value, list(method_time8$algo_and_phase), mean)
total_times8 <- data.frame(Galois = avg_times8$x[1] * 10, MST = 10*(avg_times8$x[2]+avg_times8$x[3]+avg_times8$x[5])+avg_times8$x[4])
total_times32 <- data.frame(Galois = avg_times32$x[1] * 10, MST = 10*(avg_times32$x[2]+avg_times32$x[3]+avg_times32$x[5])+avg_times32$x[4])

# Energy
method_nrg32 <- get_method_time("parsed-power-2332_ER_75i_10000_72t.csv",
							   scale_num, ins_pct, cverts, num_threads, measurement_type = "Total CPU Energy (J)")
avg_nrg32 <- aggregate(method_nrg32$value, list(method_nrg32$algo_and_phase), mean)
method_nrg8 <- get_method_time("parsed-power-238_ER_75i_10000_72t.csv",
							   scale_num, ins_pct, cverts, num_threads, measurement_type = "Total CPU Energy (J)")
avg_nrg8 <- aggregate(method_nrg8$value, list(method_nrg8$algo_and_phase), mean)
total_nrg8 <- data.frame(Galois = avg_nrg8$x[1] * 10, MST = 10*(avg_nrg8$x[2]+avg_nrg8$x[3])+avg_nrg8$x[4])
total_nrg32 <- data.frame(Galois = avg_nrg32$x[1] * 10, MST = 10*(avg_nrg32$x[2]+avg_nrg32$x[3])+avg_nrg32$x[4])

# Power
method_pwr32 <- get_method_time("parsed-power-2332_ER_75i_10000_72t.csv",
							   scale_num, ins_pct, cverts, num_threads, measurement_type = "Average CPU Power (W)")
avg_pwr32 <- aggregate(method_pwr32$value, list(method_pwr32$algo_and_phase), mean)
method_pwr8 <- get_method_time("parsed-power-238_ER_75i_10000_72t.csv",
							   scale_num, ins_pct, cverts, num_threads, measurement_type = "Average CPU Power (W)")
avg_pwr8 <- aggregate(method_pwr8$value, list(method_pwr8$algo_and_phase), mean)
total_avg_pwr8 <- data.frame(
		Galois = avg_nrg8$x[1] * 10 / total_times8$Galois[1],
		MST = (10*(avg_nrg8$x[2]+avg_nrg8$x[3])+avg_nrg8$x[4]) /
			  (10*(avg_times8$x[2]+avg_times8$x[3])+avg_times8$x[4]))
total_avg_pwr32 <- data.frame(
		Galois = avg_nrg32$x[1] * 10 / total_times32$Galois[1],
		MST = (10*(avg_nrg32$x[2]+avg_nrg32$x[3])+avg_nrg32$x[4]) /
			  (10*(avg_times32$x[2]+avg_times32$x[3])+avg_times32$x[4]))

total_times <- rbind(total_times8, total_times32,
					 total_nrg8, total_nrg32,
					 total_avg_pwr8, total_avg_pwr32)
rownames(total_times) <- c("8 EPV Total Time (s)", "32 EPV Total Time (s)",
						   "8 EPV Total Energy (J)", "32 EPV Total Energy (J)",
						   "8 EPV Avg Power (W)", "32 EPV Avg Power (W)")
ggplot(aes(y = Value, x = Phase), data = avg_times8) +
		ylab("Time (seconds)") +
		xlab("Execution Phase.Algorithm") +
		geom_bar() +
		theme(axis.text.x = element_text(angle = 90, hjust = 1))

# v Not sure about this one v
power_boxplot_with_batches("parsed-238_ER+B_75i_10000_64t_10batches.csv", 23, 75, 10000, 64,
						   measurement_type = "Time (s)")

