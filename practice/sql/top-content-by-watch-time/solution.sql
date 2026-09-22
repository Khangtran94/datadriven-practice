SELECT i.content_id, title, SUM(watch_seconds) AS lifetime_value
      -- DENSE_RANK() OVER(ORDER BY SUM(watch_seconds) DESC) AS rnk
FROM content_items AS i 
INNER JOIN content_views AS v
USING (content_id)
GROUP BY 1,2
QUALIFY DENSE_RANK() OVER(ORDER BY lifetime_value DESC) <= 3
ORDER BY 3 DESC
