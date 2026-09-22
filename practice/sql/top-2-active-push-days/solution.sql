SELECT EXTRACT(dow from sent_at) AS day_name,
      DATE(sent_at) AS send_date, COUNT(DISTINCT user_id)
FROM push_notifs
WHERE DATE(sent_at) BETWEEN '2026-08-01' AND '2026-08-07'
GROUP BY 1,2
