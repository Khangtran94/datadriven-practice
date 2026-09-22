SELECT age_bucket, COUNT(*) AS user_count
FROM users
WHERE signup_date >= '2026-04-01'
GROUP BY 1
ORDER BY 2 DESC
