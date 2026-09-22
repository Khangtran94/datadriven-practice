SELECT platform, COUNT(DISTINCT(user_id)) AS unique_openers
FROM push_notifs
WHERE opened = 1
GROUP BY 1 
ORDER BY 2 DESC
