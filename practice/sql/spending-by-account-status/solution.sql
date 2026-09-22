SELECT u.account_status,
        COUNT(t.transaction_id) AS transaction_count,
        COUNT(DISTINCT u.user_id) AS user_count,
        SUM(t.total_amount) AS total_revenue
FROM users AS u
LEFT JOIN transactions AS t
ON u.user_id = t.user_id
GROUP BY 1
HAVING COUNT(t.transaction_id) >= 5
ORDER BY 2 DESC, 4 DESC
