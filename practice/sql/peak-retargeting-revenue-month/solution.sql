select strftime('%Y-%m',impression_time) AS mnth,
      SUM(revenue) AS total_revenue,
      MAX(revenue) AS max_revenue, 
      AVG(revenue) AS avg_revenue
from ad_impressions
WHERE lower(ad_campaign) LIKE '%retarget%'
    AND revenue IS NOT NULL
GROUP BY 1
ORDER BY max_revenue desc
limit 1
