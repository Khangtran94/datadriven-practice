SELECT s.*
FROM search_queries AS s
INNER JOIN users AS u
ON s.user_id = u.user_id 
WHERE u.email IS NOT NULL AND results_count > 1
