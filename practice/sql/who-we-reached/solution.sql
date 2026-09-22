SELECT ad_campaign,
      EXTRACT(month FROM impression_time) AS month,
      COUNT(DISTINCT user_id) AS unique_users
FROM ad_impressions
GROUP BY 1,2 
