SELECT token_id, scope
FROM api_tokens
ORDER BY SUBSTRING(scope,2,1)
