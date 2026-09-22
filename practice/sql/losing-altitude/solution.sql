with junoct AS
(SELECT ad_campaign,
      STRFTIME('%Y-%m',impression_time) AS mth,
      SUM(clicked) AS total
FROM ad_impressions
WHERE STRFTIME('%Y-%m',impression_time) IN ('2026-06','2026-10')
GROUP BY 1,2),

calculate AS
(SELECT ad_campaign,
       (CASE WHEN mth = '2026-10' THEN total ELSE 0 END) - (CASE WHEN mth = '2026-06' THEN total ELSE 0 END) AS diff
FROM junoct
GROUP BY ad_campaign
ORDER BY diff)

SELECT ad_campaign
FROM calculate 
LIMIT 1
