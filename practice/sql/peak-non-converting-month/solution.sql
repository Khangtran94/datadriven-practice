with no_trans AS
(SELECT * 
FROM user_sessions
WHERE user_id NOT IN (SELECT user_id FROM transactions))

SELECT strftime('%Y-%m',session_start) AS session_month,
      COUNT(DISTINCT user_id)
FROM no_trans
WHERE extract(year from session_start) = '2026'
GROUP BY 1
ORDER BY 2 desc
limit 1
