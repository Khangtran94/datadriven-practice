SELECT extract(year from signup_date),
      COUNT(*)
FROM users
WHERE extract(month from signup_date) BETWEEN 1 and 7
GROUP BY 1
ORDER BY 1
