SELECT token_id, requests
FROM api_tokens
WHERE last_used IS NULL and scope = 'admin'
UNION 
SELECT token_id, requests
FROM api_tokens
WHERE requests IN (SELECT MAX(requests) FROM api_tokens)
UNION
SELECT token_id, requests
FROM api_tokens
WHERE requests IN (SELECT MIN(requests) FROM api_tokens where last_used IS NOT NULL)
ORDER BY requests DESC
