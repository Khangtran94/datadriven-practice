SELECT DISTINCT endpoint
FROM api_calls
WHERE endpoint NOT LIKE '%/'
UNION 
SELECT DISTINCT endpoint 
FROM rate_limits
WHERE endpoint NOT LIKE '%/'
ORDER BY endpoint
