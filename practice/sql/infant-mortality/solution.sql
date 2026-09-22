SELECT
    svc_name,
    ROUND(
        1.0 * COUNT(*) FILTER (WHERE LOWER(status) != 'healthy') / COUNT(*),
        3
    ) AS negative_ratio
FROM svc_health
WHERE status IS NOT NULL
GROUP BY svc_name
HAVING MIN(checked) >= '2026-01-01'
AND MIN(checked) < '2026-04-01'
QUALIFY negative_ratio > 0.2
