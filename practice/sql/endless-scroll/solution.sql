select user_id, sum(pages_viewed) AS total_pages
FROM user_sessions
GROUP BY 1 
order by 2 desc limit 5
