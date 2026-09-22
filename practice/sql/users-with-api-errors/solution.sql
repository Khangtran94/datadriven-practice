select count(distinct user_id)
FROM users 
INNER JOIN api_calls USING (user_id)
WHERE status >= 400
