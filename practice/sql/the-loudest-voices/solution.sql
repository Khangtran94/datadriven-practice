select sender_id AS user_id, 
    COUNT(*) AS total_messages
FROM chat_msgs
GROUP BY 1
order by 2 desc
limit 10 
