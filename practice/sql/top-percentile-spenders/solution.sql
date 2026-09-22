with total AS
(SELECT user_id, SUM(total_amount) AS total_spend
FROM transactions
WHERE transaction_date >= DATE('now', '-7 days') 
GROUP BY user_id
ORDER By 2 DESC)

select * from total
