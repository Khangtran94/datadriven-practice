SELECT LOWER(author) AS author, COUNT(DISTINCT repo_name) AS repo_count
FROM repo_commits
GROUP BY LOWER(author)
HAVING COUNT(DISTINCT repo_name) > 1
