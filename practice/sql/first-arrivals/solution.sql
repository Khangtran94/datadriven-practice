with total AS
(SELECT user_id, MIN(transaction_date) AS first_date
FROM transactions
GROUP BY 1)

SELECT first_date, COUNT(*) AS new_customers
FROM total GROUP BY 1
