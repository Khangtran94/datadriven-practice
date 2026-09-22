sELECT
  user_id,
  SUM(total_amount) AS march_total
FROM transactions
WHERE extract(month from transaction_date) = 3
GROUP BY user_id
ORDER BY march_total DESC, user_id
