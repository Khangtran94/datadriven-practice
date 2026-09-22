SELECT u.user_id, transaction_date AS the_date, 
      COUNT(*) AS total_transactions,
      SUM(total_amount) AS total_amount
FROM user_sessions AS u
INNER JOIN transactions AS t
ON u.user_id = t.user_id AND DATE(session_start) = transaction_date
GROUP BY u.user_id, the_date
