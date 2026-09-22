SELECT
  platform,
  ROUND(SUM(opened) * 1.0 / COUNT(*),3) AS open_ratio
FROM push_notifs
GROUP BY platform
ORDER BY open_ratio DESC
