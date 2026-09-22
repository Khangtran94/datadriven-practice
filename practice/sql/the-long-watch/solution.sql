SELECT content_type,     
    COUNT(*) AS items_published, 
    ROUND(AVG(duration_seconds),3) AS avg_runtime
FROM content_items
GROUP BY 1 
ORDER BY 3 desc
