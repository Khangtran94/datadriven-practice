SELECT content_type, 
    COALESCE(SUM(duration_seconds),0) AS total_duration, 
    COUNT(*) AS item_count
FROM content_items
GROUP BY 1 
order by 2 desc
