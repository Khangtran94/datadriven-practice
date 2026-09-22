SELECT creator_id,
       AVG(duration_seconds) AS avg_duration
FROM content_items
GROUP BY creator_id
HAVING SUM(duration_seconds) >= 3600
ORDER BY avg_duration DESC;
