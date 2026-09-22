with view_year AS
(SELECT * FROM content_views WHERE extract(year from viewed_at) = 2026)

SELECT content_type AS content_format,
    AVG(watch_seconds * 1.0 / duration_seconds) AS avg_completion_rate,
    COUNT(*) AS view_count 
FROM content_items
INNER JOIN view_year
USING (content_id)
WHERE duration_seconds IS NOT NULL
GROUP BY 1
ORDER BY 2 desc
