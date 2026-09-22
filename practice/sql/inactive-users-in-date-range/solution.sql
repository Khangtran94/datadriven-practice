SELECT
  u.username
FROM users AS u
LEFT JOIN user_sessions AS us
  ON u.user_id = us.user_id
  AND us.session_start >= '2026-06-01'
  AND us.session_start < '2026-07-02'
WHERE us.session_id IS NULL
ORDER BY u.username
