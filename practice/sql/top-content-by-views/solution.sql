with total AS
(SELECT content_id, 
      title,
      COUNT(*) AS view_count
FROM content_items AS c
INNER JOIN page_views AS p 
ON c.creator_id = p.user_id
GROUP BY 1,2 
QUALIFY RANK() OVER(ORDER BY view_count DESC) <= 5)

SELECT title,view_count from total
