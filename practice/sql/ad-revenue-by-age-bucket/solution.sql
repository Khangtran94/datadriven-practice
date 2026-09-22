SELECT u.age_bucket,
    SUM(a.revenue) AS total_revenue
FROM users AS u
INNER JOIN ad_impressions AS a
ON u.user_id = a.user_id
WHERE u.age_bucket IS NOT NULL
GROUP BY u.age_bucket
ORDER BY 2 DESC
