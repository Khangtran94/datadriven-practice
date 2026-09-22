SELECT SUM(quantity * total_amount)
FROM transactions
WHERE strftime('%Y-%m',transaction_date) = '2026-04'
