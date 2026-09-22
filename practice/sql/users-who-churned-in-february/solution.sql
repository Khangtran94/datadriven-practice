SELECT user_id
FROM user_sessions
GROUP BY user_id
HAVING SUM(strftime('%Y-%m', session_start) = '2026-01') > 0
   AND SUM(strftime('%Y-%m', session_start) = '2026-02') = 0;
