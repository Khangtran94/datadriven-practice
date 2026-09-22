SELECT extract(year from impression_time)
FROM ad_impressions
WHERE ad_campaign = 'HOLIDAY_PROMO'
GROUP BY 1
HAVING COUNT(*) > 1
