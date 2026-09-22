SELECT
  LOWER(platform) AS platform,
  COUNT(*) AS opened_count
FROM push_notifs
WHERE opened = 1
AND LOWER(status) = 'delivered'
AND STRFTIME('%Y', sent_at) = '2026'
GROUP BY LOWER(platform)
ORDER BY opened_count DESC, platform
