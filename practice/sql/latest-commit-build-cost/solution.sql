with each AS
(SELECT author, repo_name, max(commit_at) 
FROM repo_commits 
GROUP BY 1)

SELECT author, SUM(dur_secs) AS total_build_seconds
FROM ci_builds
INNER JOIN each 
USING (repo_name)
GROUP BY 1
