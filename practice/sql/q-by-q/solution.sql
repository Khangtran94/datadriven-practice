SELECT
    CONCAT(EXTRACT(YEAR FROM deploy_at),'-Q',EXTRACT(QUARTER FROM deploy_at)) AS quarter,
    COUNT(*) AS deploy_count
FROM deploy_logs
GROUP BY quarter
ORDER BY 2 DESC
