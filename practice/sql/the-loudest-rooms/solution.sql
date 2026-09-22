SELECT channel, COUNT(impression_id) AS impression_count
FROM chat_msgs
INNER JOIN ad_impressions
ON chat_msgs.sender_id = ad_impressions.user_id
GROUP BY 1
ORDER BY 2 desc
