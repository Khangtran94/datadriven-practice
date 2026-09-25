repo_commits \
  .filter(F.col('message').isNotNull()) \
  .groupBy(F.lower(F.col('author')).alias('author')) \
  .agg(F.count("*").alias('commit_count'),F.countDistinct('repo_name').alias('repo_count')) \
  .filter(F.col('commit_count') >= 24)
