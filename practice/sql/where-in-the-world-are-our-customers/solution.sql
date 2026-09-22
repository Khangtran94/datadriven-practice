SELECT ROUND(100.0 * SUM(CASE WHEN country = 'United States' THEN 1 ELSE 0 END) / COUNT(*),2) AS us_share_pct
FROM customers
