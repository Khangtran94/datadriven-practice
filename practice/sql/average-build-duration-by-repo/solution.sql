SELECT repo_name, AVG(dur_secs) AS avg_duration
FROM ci_builds
GROUP BY repo_name
