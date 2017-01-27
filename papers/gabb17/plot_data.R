# This is some bad bad bad R code.
# Might want to double check it.
scale <- 20
filename <- paste0("parsed",scale,".csv")
x <- read.csv(filename, header = FALSE)
bfs_time <- subset(x, x[[2]] == "BFS" & x[[3]] == "Time", c(V1,V4))
colnames(bfs_time) <- c("System","Time")
# Boxplot log = "y" may be more useful.
# TODO: Figure out why the times are so low sometimes!
boxplot(Time~System, bfs_time, ylab = "Time (seconds)")

# File reading not as useful
file_reading <- subset(x, x[[3]] == "File reading", select = c(V1,V4))
file_reading_times <- c(0,0,0)
file_reading_times[1] <- mean(file_reading[[2]][1:3])
file_reading_times[2] <- mean(file_reading[[2]][4:6])
file_reading_times[3] <- mean(file_reading[[2]][7:9])

ds_const <- subset(x, x[[3]] == "BFS" & x[[3]] == "Data structure build",
		select = c(V1,V4))

# This doesn't work well
#barplot(file_reading_times,
#		names.arg = as.character(unique(file_reading[[1]])),
#		ylab="Time (seconds)",
#		log="y")
