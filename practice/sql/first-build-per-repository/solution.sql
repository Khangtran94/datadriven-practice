SELECT repo_name, MIN(built_at) AS first_build_date
FROM ci_builds
GROUP BY 1 
ORDER BY 1
