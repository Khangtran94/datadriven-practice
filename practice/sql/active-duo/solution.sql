SELECT username
FROM users
WHERE exists (SELECT 1 FROM transactions
              WHERE users.user_id = transactions.user_id)
     AND EXISts (SELECT 1 FROM user_sessions
                 WHERE users.user_id = user_sessions.user_id)
