(
repo_commits
  .agg(F.count("*").alias('total_commits'),
      F.count_distinct(F.trim(F.lower('author'))).alias('distinct_authors'))
)
