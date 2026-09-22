SELECT r.author, AVG(comments) AS avg_comments, 
      MIN(commit_at) AS earliest_commit
FROM code_reviews AS r
INNER JOIN repo_commits USING(author)
GROUP BY 1
ORDER BY 3 
