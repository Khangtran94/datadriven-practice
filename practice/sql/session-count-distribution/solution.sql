with total AS
(select user_id, COUNT(*) AS ses_cnt
FROM user_sessions
WHERE user_id IN (SELECT user_id FROM users WHERE extract(year from signup_date) BETWEEN 2024 and 2026)
    and strftime('%Y-%m',session_start) = '2026-02'
GROUP BY 1)

SELECT ses_cnt, COUNT(user_id)
FROM total group by 1
