SELECT DISTINCT user_id
FROM push_notifs
WHERE platform = 'basic'
    -- AND user_id NOT IN (SELECT user_id FROM push_notifs WHERE platform = '
