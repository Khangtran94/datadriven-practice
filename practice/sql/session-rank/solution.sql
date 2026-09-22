
SELECT
  user_id,
  session_duration_sec,
  ROW_NUMBER() OVER (
    PARTITION BY user_id
    ORDER BY session_duration_sec DESC
  )
FROM user_sessions
WHERE session_duration_sec IS NOT NULL
order by 1, 2 desc
