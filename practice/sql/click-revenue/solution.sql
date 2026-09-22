SELECT ad_campaign, SUM(revenue) 
FROM ad_impressions
WHERE clicked = 1
GROUP BY 1 
HAVING SUM(revenue) > 5
ORDER BY 2 DESC
