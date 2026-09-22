SELECT distinct owner_id
FROM api_tokens
WHERE status = 'active'
     AND issued < '2026-11-01' AND (expires IS NULL OR expires > '2026-11-01')
