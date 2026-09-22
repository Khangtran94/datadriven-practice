SELECT SUM(total_amount)
FROM transactions AS t
INNER JOIN users AS u
USING (user_id)
WHERE extract(year from signup_date) = 2026
