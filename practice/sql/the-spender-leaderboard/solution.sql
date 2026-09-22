SELECT user_id, SUM(total_amount), row_number() OVER(ORDER BY SUM(total_amount) DESC)
FROM transactions
GROUP By 1
LIMIT 5
