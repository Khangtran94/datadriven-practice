select repo_name, COUNT(*)
FROM ci_builds
where status = 'success'
GROUP BY 1 order by 2 desc
