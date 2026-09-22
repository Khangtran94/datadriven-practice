SELECT COUNT(DISTINCT t.user_id) AS active_users_with_transactions
FROM transactions AS t
INNER JOIN users AS u USING (user_id)
WHERE strftime('%Y-%m',transaction_date) = '2026-04'
    AND u.account_status = 'active'
