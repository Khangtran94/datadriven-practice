SELECT ad_campaign,
      extract(year from impression_time) AS impression_year,
      COUNT (DISTINCT user_id) AS unique_users
FROM ad_impressions
GROUP BY 1,2
HAVING SUM(revenue) > 5
