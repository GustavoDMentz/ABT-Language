d <- read.csv('benchmark_results.csv')
w <- unique(d$workload)
p <- c('native','generated_unoptimized','generated_optimized','interpreter')
mat <- function(field) {
  out <- matrix(NA_real_,nrow=length(p),ncol=length(w),dimnames=list(p,w))
  for (i in seq_along(p)) for (j in seq_along(w)) {
    x <- d[d$path==p[i] & d$workload==w[j] & d$phase=='warm_execution',field]
    if (length(x)) out[i,j] <- x[1]
  }
  out
}
cols <- c('#4a73b8','#43a090','#ed9e4a','#bb5b76')
for (metric in c('median_ms','median_alloc_bytes')) {
  png(paste0('benchmark_',ifelse(metric=='median_ms','latency','allocations'),'.png'),1200,650)
  par(mar=c(10,5,3,2))
  m <- mat(metric)
  barplot(m,beside=TRUE,col=cols,log='y',las=2,ylab=ifelse(metric=='median_ms','Mediana (ms)','Mediana (bytes)'),main=paste('ABT 0.11.8',metric))
  legend('topright',legend=p,fill=cols,cex=.75)
  dev.off()
}
png('benchmark_throughput.png',1200,650)
par(mar=c(10,5,3,2))
m <- 1000/mat('median_ms')
matplot(t(m),type='b',log='y',lty=1,pch=1:4,col=cols,xaxt='n',xlab='',ylab='Execuções/s (1000 / mediana ms)',main='Throughput estimado')
axis(1,at=seq_along(w),labels=w,las=2)
legend('topright',legend=p,col=cols,lty=1,pch=1:4,cex=.75)
dev.off()
