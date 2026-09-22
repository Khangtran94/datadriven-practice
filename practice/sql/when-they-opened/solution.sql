SELECT Extract(month from sent_at), COUNT(*)
FROM push_notifs
WHERE opened = 1
GROUP BY 1 order by 2 desc
