SELECT content_type, COUNT(*), AVG(duration_seconds),
      COALESCE(100.0 * SUM(CASE WHEN duration_seconds IS NULL THEN 1 END) / COUNT(*),0)
 
FROM content_items
GROUP By 1 
ORDER BY 2 desc
