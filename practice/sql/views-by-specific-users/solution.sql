SELECT view_id, content_id, viewed_at, watch_seconds
FROM content_views 
INNER JOIN users USING (user_id)
WHERE username IN ('alice','aaron42','amelia')
order by 1
