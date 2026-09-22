SELECT username,   
      COALESCE(COUNT(transaction_id),0) AS transaction_count
FROM users
LEFT JOIN transactions
USING (user_id) 
GROUP BY 1
