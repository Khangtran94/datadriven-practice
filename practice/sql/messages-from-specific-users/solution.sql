SELECT *
FROM chat_msgs
WHERE sender_id IN (
  2,
  3
  )
OR content LIKE '%2%'
OR content LIKE '%3%'
