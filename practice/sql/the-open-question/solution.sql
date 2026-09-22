SELECT DATE(sent_at) AS send_date,
    1.0 * SUM(opened) / COUNT(*) AS open_rate
FROM push_notifs
GROUP BY send_date
HAVING SUM(opened) >= 1
