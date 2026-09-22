SELECT ad_campaign, SUM(revenue) 
FROM ad_impressions
WHERE extract(year from impression_time) = 2026
GROUP BY 1 
ORDER BY 2 desc
