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
boxplot(value~algorithm, data = total_time, ylab = "Time (seconds)", log = "y",
			main = paste("CC Total Time for Scale",scale, ",", pct_ins, "% insertions"), col="green")
dev.off()

