SELECT email, 
      COUNT(*) AS number_count,
      MIN(signup_date) AS earliest_date,
      MAX(signup_date) AS recently_date
FROM users
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY number_count DESC
