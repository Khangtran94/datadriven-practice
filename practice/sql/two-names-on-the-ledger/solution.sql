SELECT transaction_id, username, total_amount, SUM(total_amount) OVER(ORDER BY transaction_id) AS amount_accumulated
FROM transactions AS t
INNER JOIN users AS u ON t.user_id = u.user_id
WHERE u.username IN ('alice','aaron42')
