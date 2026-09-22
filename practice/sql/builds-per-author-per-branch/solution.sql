SELECT trigger As author, branch, COUNT(*) As build_count
FROM ci_builds
GROUP BY 1,2 
ORDER BY 1,2,3 DESC
