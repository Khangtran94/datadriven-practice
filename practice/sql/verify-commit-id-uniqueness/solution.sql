SELECT COUNT(*) AS total_count,
      COUNT(DISTINCT(commit_id)) AS unique_count
FROM repo_commits
