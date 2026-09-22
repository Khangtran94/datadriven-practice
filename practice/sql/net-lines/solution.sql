SELECT author, SUM(added) - SUM(removed)
FROM repo_commits
GROUP BY 1
