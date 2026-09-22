SELECT repo_name, 
      COUNT(*) AS commit_count
FROM repo_commits
INNER JOIN ci_builds USING (repo_name)
GROUP BY 1
order by 2 desc
