WITH sessions AS (
    SELECT
        user_id,
        ROUND(SUM(session_duration_sec) / 60.0) AS total_minutes
    FROM user_sessions
    WHERE user_id IS NOT NULL
    GROUP BY user_id
),

pages AS (
    SELECT
        user_id,
        COUNT(DISTINCT page_url) AS unique_content_count
    FROM page_views
    WHERE user_id IS NOT NULL
    GROUP BY user_id
)

SELECT
    COALESCE(s.user_id, p.user_id) AS user_id,
    COALESCE(s.total_minutes, 0) AS total_minutes,
    COALESCE(p.unique_content_count, 0) AS unique_content_count
FROM sessions s
FULL OUTER JOIN pages p
    ON s.user_id = p.user_id;
