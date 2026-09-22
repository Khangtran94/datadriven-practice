SELECT author, COUNT(*) AS commit_count
FROM repo_commits 
WHERE extract(year from commit_at) IN (2024,2025,2026)
GROUP BY 1 
ORDER BY 2 desc,1
