SELECT COUNT(*)
FROM ad_impressions 
INNER JOIN push_notifs 
USING (user_id)
WHERE campaign ILIKE '%loyalty%' and clicked = 1
