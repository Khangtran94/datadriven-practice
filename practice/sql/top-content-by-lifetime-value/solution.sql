SELECT content_id, 
      title,
      SUM(dur_ms) AS lifetime_value
FROM content_items AS c
INNER JOIN page_views AS p 
ON c.creator_id = p.user_id
GROUP BY 1,2 
QUALIFY DENSE_RANK() OVER(ORDER BY lifetime_value DESC) < 4
