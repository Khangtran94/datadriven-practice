WITH report AS (
    SELECT
        u.user_id,
        u.username,
        u.account_status,
        MAX(s.session_start) AS last_login,
        COALESCE(SUM(t.total_amount), 0) AS total_spend
    FROM users u
    LEFT JOIN user_sessions s
        ON u.user_id = s.user_id
    LEFT JOIN transactions t
        ON u.user_id = t.user_id
    WHERE u.account_status = 'active'
    GROUP BY
        u.user_id,
        u.username,
        u.account_status
)
SELECT
    username,
    account_status,
    last_login,
    total_spend
FROM report
WHERE last_login < (
    SELECT MAX(session_start) - INTERVAL '90 days'
    FROM user_sessions
)
   OR last_login IS NULL;
