
SELECT
  msg_id,
  topic,
  part_key,
  payload,
  produced,
  consumer
FROM stream_msgs
WHERE topic = 'user-events'
UNION ALL
SELECT
  msg_id,
  topic,
  part_key,
  payload,
  produced,
  consumer
FROM stream_msgs
WHERE topic = 'user-events'
ORDER BY msg_id
