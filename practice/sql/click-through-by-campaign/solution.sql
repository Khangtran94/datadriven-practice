SELECT ad_campaign,
    COUNT(impression_id) AS total_impressions,
    ROUND(100.0 * SUM(clicked) / COUNT(*),2) AS clicked_pct,
    100 - ROUND(100.0 * SUM(clicked) / COUNT(*),2) AS not_clicked_pct 
FROM ad_impressions
GROUP BY ad_campaign
