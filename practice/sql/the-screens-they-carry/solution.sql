SELECT d.device_type,
      COUNT(DISTINCT(d.device_id)) AS device_count
FROM users AS u
INNER JOIN user_sessions AS us ON u.user_id = us.user_id
INNER JOIN devices AS d ON d.device_id = us.device_id
WHERE age_bucket = '25-34' AND account_status = 'active'
GROUP BY 1
