SELECT u.username AS username,
    ROUND(SUM(revenue),2) AS total_revenue
FROM ad_impressions AS a
INNER JOIN users AS u
ON a.user_id = u.user_id
WHERE clicked > 0
GROUP BY username
ORDER BY total_revenue DESC
