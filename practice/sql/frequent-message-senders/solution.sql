SELECT sender_id, COUNT(*) 
FROM chat_msgs
GROUP BY sender_id
HAVING COUNT(*) > 1
