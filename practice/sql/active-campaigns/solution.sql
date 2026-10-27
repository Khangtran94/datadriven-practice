SELECT ad_campaign,
    COUNT(*) AS impressions,
    SUM(revenue) AS total_revenue,
    ROUND(100.0 * SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) / COUNT(*),1) AS ctr
FROM ad_impressions
GROUP BY ad_campaign
