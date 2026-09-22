select repo_name,
      ROUND(100.0 * SUM(CASE WHEN status = 'failed' then 1 end) / COUNT(*),2) AS failure_pct
FROM ci_builds
GROUP BY 1 
ORDER BY 2 desc
