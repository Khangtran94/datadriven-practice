SELECT
    username,
    SUM(total_amount) AS total,
    DENSE_RANK() OVER (ORDER BY SUM(total_amount) DESC) AS rnk
FROM transactions AS t
INNER JOIN users AS u
USING (user_id)
GROUP BY username, t.user_id
QUALIFY rnk <= 5;
