library(ggplot2)
x <- read.delim("client.dat", header=FALSE, col.names=c("date", "count"), colClasses=c("POSIXct", "numeric"))

png("client-count.png", width=720, height=480)
qplot(date, data=x, geom="bar", weight=count, binwidth=86400, ylab="client requests per day")
