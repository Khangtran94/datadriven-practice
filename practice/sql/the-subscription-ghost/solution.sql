with compare AS
(SELECT transaction_id, user_id, product_id, total_amount, transaction_date,
      LAG(total_amount) OVER(PARTITION BY user_id, product_id ORDER BY transaction_date) AS prev_amount,
      LAG(transaction_date) OVER(PARTITION BY user_id, product_id ORDER BY transaction_date) AS prev_tran
FROM transactions
-- WHERE user_id IS NOT null AND product_id IS NOT NULL
ORDER BY user_id, product_id, transaction_date),

flag AS
(SELECT *,transaction_date::date- prev_tran::date AS day_diff
FROM compare
WHERE day_diff <= 35 AND prev_amount = total_amount)

SELECT transaction_id, user_id, product_id, total_amount, transaction_date
FROM flag 
ORDER BY transaction_date
