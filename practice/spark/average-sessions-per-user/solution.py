total = (
user_sessions
  .groupBy('user_id')
  .agg(F.count("*").alias('session'))
)

total.agg(F.sum('session') / total.count()).alias('avg_sessions_per_user')
