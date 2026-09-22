SELECT u.user_id,
    COUNT(notif_id) FILTER(WHERE lower(status) = 'delivered') AS delivered_count,
    COUNT(notif_id) FILTER(WHERE opened = 1) AS opened_count,
    COUNT(notif_id) FILTER(WHERE lower(status) = 'failed') AS failed_count
FROM users AS u
INNER JOIN push_notifs
USING (user_id)
GROUP BY 1
