with total AS
(SELECT user_id, transaction_date,
      LAG(transaction_date) OVER(PARTITION BY user_id ORDER BY transaction_date) AS prev
FROM transactions),

unique_user AS
(SELECT *, DATEADD(day, 7, prev) AS next_7_day
FROM total
WHERE prev IS NOT NULL 
    AND transaction_date < next_7_day)

SELECT DISTINCT user_id
FROM unique_user
ORDER BY 1
