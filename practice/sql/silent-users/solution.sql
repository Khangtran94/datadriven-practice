SELECT username, signup_date
FROM users
WHERE NOT EXISTS (SELECT 1
              FROM search_queries
              WHERE search_queries.user_id = users.user_id)
