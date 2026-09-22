SELECT repo_name, COUNT(*) AS commit_count
FROM repo_commits
GROUP BY 1
HAVING COUNT(*) > (SELECT COUNT(*) / COUNT(DISTINCT repo_name) FROM repo_commits)
