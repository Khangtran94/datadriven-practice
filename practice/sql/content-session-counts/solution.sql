SELECT page_url, COUNT(DISTINCT session_id) AS unique_sessions
FROM page_views AS p
INNER JOIN user_sessions AS u
USING (user_id)
GROUP BY page_url
ORDER BY 2 DESC
