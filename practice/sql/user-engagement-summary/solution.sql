with total_s AS
(SELECT user_id, COUNT(session_id) AS total_session
FROM user_sessions
WHERE user_id IS NOT NULL
GROUP BY user_id),

total_q AS
(SELECT user_id, COUNT(query_id) AS total_query
FROM search_queries
WHERE user_id IS NOT NULL
GROUP BY user_id)

SELECT COALESCE(a.user_id,b.user_id) AS user_id,
      COALESCE(total_session,0) AS total_sessions,
      COALESCE(total_query,0) AS total_queries
FROM total_s AS a
FULL OUTER JOIN total_q AS b
ON a.user_id = b.user_id
ORDER BY 1
