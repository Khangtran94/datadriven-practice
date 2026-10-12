user_sessions.join(broadcast(devices),'device_id')
  .groupBy('device_type')
  .agg(
    F.round(F.avg('session_duration_sec'),3).alias('avg_duration'),
    F.max('session_duration_sec').alias('max_duration'),
    F.count("*").alias('session_count'))
  .filter(F.col('session_count') >= 35)
