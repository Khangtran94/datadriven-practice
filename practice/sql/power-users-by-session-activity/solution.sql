with total AS
(SELECT u.user_id, 
      u.username, 
      s.session_start,
      s.pages_viewed
FROM users AS u
INNER JOIN user_sessions AS s
ON u.user_id = s.user_id AND account_status = 'active'
ORDER BY u.user_id, session_start)

SELECT user_id, username, 
        COUNT(session_start) AS session_count,
        SUM(pages_viewed) AS total_pages
FROM total
GROUP BY user_id, username
HAVING COUNT(session_start) > 3 and SUM(pages_viewed) > 100
ORDER BY total_pages DESC
