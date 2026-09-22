with total AS
(SELECT repo_name,  
    COALESCE(SUM(dur_secs), 0) AS total_dur_secs
FROM ci_builds
WHERE strftime('%Y-%m',built_at) = '2026-01'
GROUP BY 1)

SELECT DISTINCT repo_name, COALesCE(total_dur_secs,0)
FROM ci_builds
LEFT JOIN total
USING (repo_name)
