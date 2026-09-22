SELECT repo_name, COUNT(*) AS build_count
FROM ci_builds AS b
GROUP BY repo_name
order by 2 desc
