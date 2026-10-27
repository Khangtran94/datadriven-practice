(users
  .filter(F.col('age_bucket') == '25-34')
  .join(experiments, 'user_id')
  .groupBy('platform')
  .agg(F.round(F.avg('outcome')).alias('avg_satisfaction'))
  )
