SELECT
    endpoint,
    COUNT(*) AS call_count,
    DENSE_RANK() OVER (ORDER BY COUNT(*)) AS rnk
FROM api_calls
WHERE LOWER(method) = 'post'
GROUP BY 1
QUALIFY rnk <= 2
ORDER BY call_count;
