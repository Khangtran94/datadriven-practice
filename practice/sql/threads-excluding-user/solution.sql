SELECT COUNT(*) 
FROM (
    SELECT DISTINCT sender_id, reply_to 
    FROM chat_msgs 
    WHERE reply_to IS NOT NULL 
      AND sender_id != 1 
      AND reply_to != 1
) AS unique_pairs;
