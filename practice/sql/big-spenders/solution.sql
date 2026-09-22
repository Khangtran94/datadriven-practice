SELECT user_id, SUM(total_amount) AS lifetime_spend,
    COUNT(*) AS tx_count
FROM transactions
GROUP BY 1
HAVING lifetime_spend > 5000
ORDER BY 2 desc
