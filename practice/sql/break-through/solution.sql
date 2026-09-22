SELECT ad_campaign, 
      ROUND(100.0 * SUM(clicked) / COUNT(*),2) AS ctr_pct,
      SUM(revenue) AS total_revenue,
      COUNT(*) AS impressions
FROM ad_impressions
GROUP BY ad_campaign
HAVING ROUND(100.0 * SUM(clicked) / COUNT(*),3) > 20
ORDER BY 2 DESC
