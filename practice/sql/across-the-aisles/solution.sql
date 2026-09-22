with combine AS
(SELECT u.user_id,
        p.product_id, 
        category
FROM users AS u
INNER JOIN transactions USING (user_id)
INNER JOIN products AS p USING (product_id))

SELECT user_id, COUNT(DISTINCT category) AS category_count
FROM combine
GROUP BY user_id
HAVING category_count > 1
ORDER BY 2 desc
