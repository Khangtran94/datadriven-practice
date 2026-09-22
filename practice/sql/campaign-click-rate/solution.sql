SELECT ad_campaign,
      ROUND(100.0* SUM(clicked) / COUNT(*),2) AS clicked_pct
FROM ad_impressions
WHERE user_id IN (SELECT distinct user_id from page_views)
GROUP BY 1 
order by 2 desc
