SELECT SUBSTRING(username, 1,1) AS initial,
      COUNT(*) AS user_count, 
      ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM users),1) AS pct
FROM users
GROUP BY 1
ORDER BY 2 DESC
