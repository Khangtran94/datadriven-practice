with total as
(SELECT feat_name
FROM ml_features
WHERE source IN ('ad_impressions','search_queries')
GROUP BY feat_name
HAVING COUNT(distinct source) = 2)

SELECT feat_name,
      SUM(CASE WHEN source  = 'ad_impressions' then 1 end) AS ad_rows,
      SUM(CASE WHEN source  = 'search_queries' then 1 end) AS search_rows,
      MAX(CASE WHEN source  = 'ad_impressions' then updated end) AS last_seen_ad,
      MAX(CASE WHEN source  = 'search_queries' then updated end) AS last_seen_search
FROM ml_features
WHERE feat_name IN (SELECT feat_name FROM total)
GROUP BY 1
