with total AS
(SELECT svc_name, strftime('%Y-%m', deploy_at) AS deploy_month,
      COUNT(*) AS deploy_count,
      LAG(COUNT(*)) OVER(PARTITION BY svc_name ORDER BY strftime('%Y-%m', deploy_at)) AS prev_count
FROM deploy_logs
GROUP BY 1,2 
ORDER BY 1,2)

SELECT *, (100 * (deploy_count - prev_count) / prev_count) AS pct_change
FROM total
WHERE prev_count IS NOT NULL
