SELECT user_id, total_amount, transaction_date
FROM transactions
QUALIFY row_number() OVER(PARTITION BY user_id order by transaction_date) =2
