with total AS
(SELECT user_id, SUM(clicked) AS click
FROM ad_impressions
GROUP BY 1)

SELECT CASE WHEN click > 0 THEN 'has_click'
        ELSE 'no_click' END AS click_group,
        COUNT(*) AS user_count
FROM users
LEFT JOIN total
USING (user_id)
GROUP BY 1
