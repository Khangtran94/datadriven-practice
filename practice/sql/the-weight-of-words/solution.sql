SELECT lower(author), ROUND(AVG(LENGTH(message)),2),
       COUNT(*), ROUND(AVG(added),2)
FROM repo_commits
WHERE LENGTH(message) > 0
GROUP BY 1
HAVING COUNT(*) > 2
ORDER BY 2 DESC
