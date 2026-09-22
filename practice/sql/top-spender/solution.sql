SELECT username, 
    SUM(total_amount) AS total_spend
FROM users 
INNER JOIN transactions 
USING (user_id)
GROUP BY user_id, username
HAVING total_spend > (SELECT max(price) FROM products) 
ORDER BY 2 desc
