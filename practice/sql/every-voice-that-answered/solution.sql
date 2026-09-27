select reply_to AS content_id,
    COUNT(DISTINCT(CONCAT(sender_id,'_',channel))) AS reporter_count
from chat_msgs
WHERE reply_to IS NOT NULL
GROUP BY content_id
