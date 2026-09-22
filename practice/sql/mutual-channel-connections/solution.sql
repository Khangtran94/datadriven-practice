SELECT DISTINCT sender_id 
FROM chat_msgs
WHERE channel IN (SELECT DISTINCT channel FROM chat_msgs WHERE sender_id IN (197, 585))
      AND sender_id NOT IN (197, 585)
