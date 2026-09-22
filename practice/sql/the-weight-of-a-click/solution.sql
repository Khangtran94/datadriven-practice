WITH event_counts AS (
    SELECT
        event_type,
        COUNT(DISTINCT user_id) AS unique_users
    FROM event_data
    WHERE event_type IN (
        'page_view',
        'search',
        'checkout_start',
        'purchase'
    )
    GROUP BY event_type
),
engaged AS (
    SELECT SUM(unique_users) AS engaged_users
    FROM event_counts
    )

SELECT
    e.event_type,
    e.unique_users,
    ROUND(
        100.0 * e.unique_users / g.engaged_users,
       1
    ) AS pct_of_engaged
FROM event_counts e
CROSS JOIN engaged g
ORDER BY e.unique_users DESC;
