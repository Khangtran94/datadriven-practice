SELECT ROUND(100.0 * SUM(CASE WHEN expires IS NULL THEN 1 ELSE 0 END) / COUNT(*),2) AS perpetual_pct
FROM api_tokens
