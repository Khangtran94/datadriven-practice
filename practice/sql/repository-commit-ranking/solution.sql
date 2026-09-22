SELECT repo_name,SUM(added) AS total_added,DENSE_RANK() OVER(ORDER BY SUM(added) DESC) AS rank
FROm repo_commits
GROUP BY 1
