with total AS
(SELECT user_id, transaction_date, 
      LAG(transaction_date) OVER(PARTITION BY user_id ORDER BY transaction_date) AS prev,
      DATEDIFF(
        DAY,
        LAG(transaction_date) OVER (
            PARTITION BY user_id
            ORDER BY transaction_date
        ),
        transaction_date) AS day_difference
FROM transactions
WHERE user_id IS NOT NULL
QUALIFY day_difference <= 7)


SELECT DISTINCT user_id FROM total
