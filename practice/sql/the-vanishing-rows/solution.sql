SELECT view_id, c.user_id, username
FROM content_views AS c
INNER JOIN users USING (user_id)
