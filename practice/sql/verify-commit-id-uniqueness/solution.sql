repo_commits.agg(F.count("*").alias('total_commits'),F.countDistinct('author').alias('distinct_authors'))
