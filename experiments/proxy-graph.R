library(ggplot2)
x <- read.delim("proxy.dat", header=FALSE, col.names=c("date", "interval"), colClasses=c("POSIXct", "numeric"))

png("proxy-count.png", width=720, height=480)
qplot(date, data=x, geom="bar", weight=interval/10, binwidth=86400, ylab="proxy requests per day")
