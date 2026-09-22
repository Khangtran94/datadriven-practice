SELECT *
FROM api_tokens
WHERE scope = 'read' AND last_used IS NULL
