(stream_msgs
  .groupBy('topic')
  .agg(F.count('*').alias('num_messages'))
  .filter(F.col('num_messages') < 11))
