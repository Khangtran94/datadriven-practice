with event AS
(SELECT DISTINCT user_id, FIRST_VALUE(event_type) OVER(PARTITION BY user_id ORDER BY event_timestamp) AS first_event
FROM event_data)

SELECT e.user_id, COUNT(event_type) AS purchase_count
FROM event AS e
LEFT JOIN event_data AS r
ON e.user_id = r.user_id AND event_type = 'purchase'
WHERE first_event = 'page_view'
GROUP BY e.user_id
ORDER BY purchase_count DESC, e.user_id
