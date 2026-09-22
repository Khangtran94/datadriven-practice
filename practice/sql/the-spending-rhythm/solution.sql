SELECT user_id, strftime('%Y-%m', transaction_date), count(*)
FROM transactions
GROUP BY 1,2 
