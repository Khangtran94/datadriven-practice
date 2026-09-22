SELECT strftime('%Y-%m',transaction_date), SUM(total_amount)
FROm transactions
GROUP BY 1 order by 2 desc limit 3
