SELECT age_bucket, COUNT(*) AS user_count
FROM users
GROUP BY 1
ORDER BY 1 DESC
