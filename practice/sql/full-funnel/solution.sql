SELECT username
FROM users 
WHERE user_id IN 
(SELECT user_id 
FROM search_queries
INNER JOIN page_views USING (user_id)
INNER JOIN transactions USING(user_id))
