
filename <- "parsed_sleep_baseline.csv"
avgs <- tabulate_data <- function(filename)
{
	x <- read.csv(filename, header = TRUE)
	avgs <- aggregate(x$value, list(x$package, x$algorithm, x$threads, x$measurement), mean)
	colnames(avgs) <- c("Parallel?", "Algorithm", "Threads", "Measurement", "Value (mean)")
	return(avgs)
}
avgs <- tabulate_data(filename)
print(avgs)
