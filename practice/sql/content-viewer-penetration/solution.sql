SELECT
  ROUND(
    100 * COUNT(DISTINCT cv.user_id) / COUNT(DISTINCT 
      u.user_id
      ),
    2
    ) AS viewer_pct
FROM users AS u
LEFT JOIN content_views AS cv
  ON u.user_id = cv.user_id
