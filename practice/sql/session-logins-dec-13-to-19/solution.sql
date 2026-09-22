SELECT distinct user_id
FROM user_sessions
WHERE Date(session_start) BETWEEN '2026-12-13' AND '2026-12-19'
