SELECT user_id, transaction_date, total_amount,
      SUM(total_amount) OVER(PARTITION BY user_id ORDER BY transaction_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_sum
FROM transactions
