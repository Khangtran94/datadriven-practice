SELECT ad_campaign, SUM(revenue) / count(*)
FROM ad_impressions
GROUP BY 1 
order by 2 desc
