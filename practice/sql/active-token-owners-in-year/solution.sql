SELECT COUNT(DISTINCT owner_id)
FROM api_tokens
WHERE strftime('%Y',issued) = '2026'
