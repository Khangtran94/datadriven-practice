SELECT ad_campaign, ROUND(1.0 * SUM(revenue) / SUM(clicked),3) AS rpc
FROM ad_impressions
WHERE extract(year from impression_time) BETWEEN 2025 AND 2026
GROUP BY 1
