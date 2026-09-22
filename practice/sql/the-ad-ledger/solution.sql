SELECT SUM(revenue)
FROM ad_impressions
WHERE extract(year from impression_time) = 2026
