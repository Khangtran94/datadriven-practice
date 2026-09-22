select repo_name, extract(year from built_at), avg(dur_secs)
FROM ci_builds
GROUP BY 1, 2
ORDER BY 3 desc
