SELECT content_type, round(AVG(watch_seconds),3) AS avg_watch_time
FROM content_items
INNER JOIN content_views
USING (content_id)
GROUP BY 1 
ORDER BY 2 desc
