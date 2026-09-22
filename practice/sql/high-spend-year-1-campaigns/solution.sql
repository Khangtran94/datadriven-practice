SELECT ad_campaign, COUNT(DISTINCT user_id)
FROM ad_impressions
WHERE EXTRACT(year from impression_time) = '2025'
GROUP BY 1
HAVING SUM(revenue) > 5
ORDER BY 1 
