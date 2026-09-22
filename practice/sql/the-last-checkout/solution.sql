with calculate AS
(SELECT *, DENSE_RANK() OVER(PARTITION BY user_id ORDER BY transaction_date DESC) AS rnk
FROM transactions
ORDER BY user_id, transaction_date DESC),

simple AS
(SELECT transaction_date, user_id
FROM calculate
WHERE rnk = 1)

SELECT transaction_date, user_id, COUNT(*) AS number_purchase
FROM simple
GROUP BY transaction_date, user_id
ORDER BY transaction_date
