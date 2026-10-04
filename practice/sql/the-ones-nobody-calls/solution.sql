SELECT endpoint,
       COUNT(*) AS call_count,
       DENSE_RANK() OVER (ORDER BY COUNT(*)) AS rnk
FROM api_calls
WHERE UPPER(method) = 'POST'
GROUP BY endpoint
QUALIFY rnk <= 3
