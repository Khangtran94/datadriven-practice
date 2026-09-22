SELECT DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS rnk,
       sender_id, COUNT(*) AS total_messages
FROM chat_msgs
GROUP BY 2
