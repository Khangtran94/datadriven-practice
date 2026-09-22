SELECT username, COUNT(transaction_id) AS txn_count,
      DENSE_RANK() OVER(order by count(transaction_id) DESC) AS rnk
FROM users 
INNER JOIN transactions USING (user_id)
GROUP BY 1 
QUALIFY rnk <= 5
ORDER BY 1
