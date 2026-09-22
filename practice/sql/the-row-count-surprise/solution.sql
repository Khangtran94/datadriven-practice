SELECT
  'inner_join' AS join_type,
  COUNT(*) AS row_count
FROM users AS u
INNER JOIN ad_impressions AS ai
  ON u.user_id = ai.user_id
  
UNION ALL
  
SELECT
  'left_join',
  COUNT(*)
FROM users AS u
LEFT JOIN ad_impressions AS ai
  ON u.user_id = ai.user_id
  
UNION ALL
  
SELECT
  'full_outer_join',
  COUNT(*)
FROM users AS u
FULL OUTER JOIN ad_impressions AS ai
  ON u.user_id = ai.user_id
