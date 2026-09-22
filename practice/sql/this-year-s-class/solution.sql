SELECT
  COUNT(*) AS signup_count
FROM users
WHERE STRFTIME('%Y', signup_date) = '2025'
