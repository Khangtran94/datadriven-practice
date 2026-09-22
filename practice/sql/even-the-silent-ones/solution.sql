WITH sessions AS (
    SELECT
        user_id,
        COUNT(session_id) AS session_count
    FROM user_sessions
    GROUP BY user_id
),

spending AS (
    SELECT
        user_id,
        SUM(total_amount) AS total_amount
    FROM transactions
    GROUP BY user_id
)

SELECT
    u.username,
    COALESCE(s.session_count, 0) AS session_count,
    COALESCE(p.total_amount, 0) AS total_amount
FROM users u
LEFT JOIN sessions s
    USING (user_id)
LEFT JOIN spending p
    USING (user_id);
