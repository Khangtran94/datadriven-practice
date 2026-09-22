SELECT ABS(
    MAX(CASE WHEN department = 'Engineering' then total_amount ELSE 0 END) 
    - MAX(CASE WHEN department = 'Marketing' then total_amount ELSE 0 END)) AS spend_gap
FROM transactions
INNER JOIN employees USING (user_id)
