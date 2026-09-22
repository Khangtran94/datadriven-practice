SELECT user_id, SUM(total_amount) AS total_spend
FROM transactions
GROUP BY user_id
QUALIFY DENSE_RANK() OVER(ORDER BY total_spend DESC) = 3
