SELECT reply_to AS recipient_id, 
      msg_type, COUNT(*) AS msg_count
FROM chat_msgs
WHERE msg_type NOT IN ('text','image') and reply_to is not null
GROUP BY 1,2
