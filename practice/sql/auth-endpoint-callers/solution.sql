SELECT u.user_id, 
    username, email, call_id, endpoint
FROM users AS u
INNER JOIN api_calls AS a
ON u.user_id = a.user_id
WHERE endpoint LIKE '%auth%'
ORDER BY u.user_id
