SELECT lower(campaign), extract(year from sent_at), 
      ROUND(1.0 * COUNT(*) / SUM(opened),3) AS cost_per_acquisition
FROM push_notifs
WHERE lower(campaign) like '%promo%'
GROUP BY 1,2
