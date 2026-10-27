mean = svc_health.groupBy('region')
      .agg(F.round(F.avg('latency'),3).alias('avg_region_latency'))
      
svc_health.join(broadcast(mean),'region')
  .select('svc_name','region','latency','avg_region_latency')
  .orderBy('region','svc_name','latency')
