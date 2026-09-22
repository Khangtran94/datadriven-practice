SELECT strftime('%Y-%m', signup_date), COUNT(*) AS signup_count, 
      cAST(COUNT(*) AS Float) AS signup_count
FROM users
GROUP BY 1
