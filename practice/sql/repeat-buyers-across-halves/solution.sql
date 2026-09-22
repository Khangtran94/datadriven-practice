with total AS
(SELECT *, 
      CASE WHEN transaction_date >= '2026-01-01' AND transaction_date < '2026-07-01' THEN 'first_half'
      ELSE 'second_half' END AS type 
FROM transactions
WHERE EXTRACT(YEAR FROM transaction_date) = 2026)

SELECT user_id
FROM total
GROUP BY user_id
HAVING COUNT(DISTINCT type) = 2;
