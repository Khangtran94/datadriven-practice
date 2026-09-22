with total AS
(SELECT content_type, COUNT(*), DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS rnk
FROM content_items AS ct
INNER JOIN users AS u 
ON ct.creator_id = u.user_id
GROUP BY 1 
ORDER BY 2 DESC)

SELECT *
FROM content_items 
WHERE content_type = (SELECT content_type FROM total WHERE rnk = 2)
