SELECT 
    account_status,
    COUNT(*) AS user_count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM users) AS pct
FROM users
GROUP BY account_status;
