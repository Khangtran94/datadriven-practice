SELECT content_id, title, content_type, creator_id
FROM content_items
WHERE creator_id IN (SELECT user_id FROM users WHERE username IN ('alice','aaron42','amelia'))
