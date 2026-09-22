with more AS
(SELECT user_id
FROM transactions
GROUP BY user_id 
HAVING COUNT(*) > 1)

SELECT user_id, total_amount, transaction_date
FROM transactions
WHERE EXISTS (SELECT 1 FROM more WHERE more.user_id = transactions.user_id)
QUALIFY row_number() OVER(PARTITION BY user_id order by transaction_date) =2  
