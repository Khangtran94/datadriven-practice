with search AS
(SELECT user_id
FROM search_queries
WHERE search_term ILIKE '%laptop%')

SELECT 'laptop deals' AS search_term, 
      COUNT(*) AS impression_count
FROM ad_impressions
WHERE EXISTS (SELECT 1 FROM search WHERE search.user_id = ad_impressions.user_id)
