SELECT distinct client
FROM rate_limits
WHERE blocked > 0
