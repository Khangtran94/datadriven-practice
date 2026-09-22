SELECT creator_id, AVG(session_duration_sec) AS avg_session_duration
FROm user_sessions AS u
INNER JOIN content_items AS c
ON u.user_id = c.creator_id
GROUP BY 1
