SELECT UPPER(method) AS method, status,
    ROUND(1.00 * COUNT(*) / (SELECT COUNT(*) FROM api_calls),3) AS fraction
FROM api_calls
GROUP BY 1,2
