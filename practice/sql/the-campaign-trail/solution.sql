SELECT ad_campaign
FROM ad_impressions
WHERE extract(year from impression_time) = 2025
GROUP BY 1 
HAVING SUM(revenue) > 5
