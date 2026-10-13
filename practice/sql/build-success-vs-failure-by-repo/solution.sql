ci_builds
  .groupBy('repo_name')
  .agg(
    F.count(F.when(F.col("status") == "success", 1)).alias("success_count"),
    F.count(F.when(F.col("status") == "failure", 1)).alias("failure_count"),
    F.round(F.avg("dur_secs"), 3).alias("avg_duration")
  )
