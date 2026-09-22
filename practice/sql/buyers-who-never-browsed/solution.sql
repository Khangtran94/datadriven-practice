SELECT username, total_amount AS total_spent
FROM users AS u
INNER JOIN transactions AS t 
ON u.user_id = t.user_id
WHERE t.transaction_date >= DATE('now', '-30 days')
    AND NOT EXISTS (SELECT 1 FROM page_views AS p WHERE p.user_id = u.user_id)
