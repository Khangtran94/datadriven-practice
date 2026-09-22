SELECT ad_campaign, SUM(revenue)
FROM ad_impressions GROUP BY 1
