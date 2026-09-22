SELECT creator_id, 
      content_type,
      COUNT(*) AS cnt,
    DENSE_RANK() OVER (PARTITION BY creator_id ORDER BY COUNT(*) DESC) AS rnk
FROM content_items
GROUP BY 1, 2
QUALIFY rnk = 1
