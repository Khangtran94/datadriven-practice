SELECT ad_campaign,
      SUM(clicked) AS total_clicks,
      MAX(revenue) AS max_impression_revenue
FROM ad_impressions
GROUP BY 1
ORDER BY 2 DESC
