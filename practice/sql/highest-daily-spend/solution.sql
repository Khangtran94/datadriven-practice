SELECT username, SUM(total_amount) AS total_daily_spend,transaction_date,
      DENSE_RANK() OVER(PARTITION BY transaction_date ORDER BY SUM(total_amount) DESC) AS rnk
FROM users
INNER JOIN transactions USING (user_id)
WHERE transaction_date BETWEEN '2026-03-01' AND '2026-06-01'
GROUP BY transaction_date, username

QUALIFY rnk = 1
