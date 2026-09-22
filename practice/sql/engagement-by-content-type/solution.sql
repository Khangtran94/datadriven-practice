SELECT content_type,
      COALESCE(sum(duration_seconds),0) AS total_duration,
      COUNT(*) AS item_count
FROM content_items
-- WHERE duration_seconds IS NOT NULL
GROUP BY 1 ORDER BY 2 desc
