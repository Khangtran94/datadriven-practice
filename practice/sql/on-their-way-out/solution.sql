SELECT user_id, SUM(pages_viewed) AS total_page_viewed
FROM user_sessions
GROUP BY 1
HAVING SUM(pages_viewed) BETWEEN 1 AND 9 
ORDER BY 2 
