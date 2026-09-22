SELECT content_type, 
      COUNT(s.session_id)
FROM content_items AS c
INNER JOIN user_sessions AS s
ON s.user_id = c.creator_id
GROUP BY 1
ORDER BY 1
