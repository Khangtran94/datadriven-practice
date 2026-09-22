with combine AS
(SELECT age_bucket, u.user_id, SUM(total_amount) AS total_spent
FROM users AS u 
INNER JOIN transactions 
USING (user_id)
GROUP BY 1,2)

SELECT *
FROM combine
QUALIFY ROW_NUMBER() OVER(PARTITION BY age_bucket ORDER BY total_spent DESC) <= 3
