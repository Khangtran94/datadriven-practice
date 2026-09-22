SELECT ad_campaign, COUNT(DISTINCT user_id) AS users_reached
FROM ad_impressions
LEFT JOIN users
USING (user_id)
WHERE clicked > 0
GROUP BY 1 
ORDER BY 2 desc
