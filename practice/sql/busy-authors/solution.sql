SELECT lower(author) AS author, 
      COUNT(*) AS commit_count, 
      COUNT(DISTINCT repo_name) AS repo_count
FROM repo_commits
WHERE message IS NOT NULL
GROUP BY 1
HAVING COUNT(*) >= 24
