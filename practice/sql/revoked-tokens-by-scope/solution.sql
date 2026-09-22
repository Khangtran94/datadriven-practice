select scope, COUNT(*) AS blocked_count
FROM api_tokens
WHERE lower(status) = 'revoked' AND issued <= '2026-12-31'
AND (
  expires IS NULL
  OR expires >= '2026-12-01')
GROUP BY 1
