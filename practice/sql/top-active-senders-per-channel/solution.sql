SELECT channel, sender_id, COUNT(*) AS msg_count
FROM chat_msgs
GROUP BY 1,2
QUALIFY DENSE_RANK() OVER(PARTITION BY channel ORDER BY msg_count DESC) <= 3
