SELECT channel, 
      COUNT(msg_id) AS total_messages,
      COUNT(DISTINCT sender_id) AS unique_senders,
      ROUND(100.0 * SUM(edited) / COUNT(*),1) AS edited_pct
FROM chat_msgs
GROUP BY channel
HAVING COUNT(msg_id) >= 5
ORDER BY total_messages DESC
