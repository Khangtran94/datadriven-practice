SELECT user_id, username, email, token_id, scope
FROM users 
INNER JOIN api_tokens
ON users.user_id = api_tokens.owner_id
WHERE LOWER(scope) LIKE '%admin%'
ORDER BY user_id, issued
