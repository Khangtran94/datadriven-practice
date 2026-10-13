SELECT repo_name,
    COUNT(*) FILTER(WHERE status = 'success') AS success_count,
    COUNT(*) FILTER(WHERE status = 'failure') AS failure_count,
    ROUND(AVG(dur_secs),3) AS avg_duration
FROM ci_builds
GROUP BY 1
