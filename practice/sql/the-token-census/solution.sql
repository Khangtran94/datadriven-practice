SELECT COUNT(DISTINCT owner_id)
FROM api_tokens
WHERE EXTRACT(year from issued) = 2026
