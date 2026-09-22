SELECT SUM(
    quantity * total_amount
    ) AS total_revenue
FROM transactions
INNER JOIN users
USING (user_id)
WHERE account_status = 'active'
    AND strftime('%Y-%m',transaction_date) = '2026-04'
