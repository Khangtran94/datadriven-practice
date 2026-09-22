SELECT user_id, total_amount, transaction_date,
      LAG(total_amount) OVER(PARTITION BY user_id ORDER BY transaction_date) AS prev_amount
FROM transactions
