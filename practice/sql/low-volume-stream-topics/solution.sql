SELECT topic, COUNT(*) AS msg_count
FROM stream_msgs
GROUP BY topic
HAVING COUNT(*) < 11 
