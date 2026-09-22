SELECT u.username, 
      account_status, 
      signup_date, 
      session_start
FROM users AS u 
LEFT JOIN user_sessions AS s ON u.user_id = s.user_id
ORDER BY 1,4
