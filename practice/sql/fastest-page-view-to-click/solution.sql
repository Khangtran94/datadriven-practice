with old AS
(SELECT user_id, 
      event_type, 
      event_timestamp,
      LAG(event_type) OVER(ORDER BY event_timestamp) AS prev_type,
      LAG(event_timestamp) OVER(ORDER BY event_timestamp) AS prev_time,
      LAG(user_id) OVER(ORDER BY event_timestamp) AS prev_user
FROM event_data
WHERE event_type IN ('page_view','button_click')),

compare AS
(SELECT *, 
    CASE WHEN prev_type = 'page_view' AND event_type = 'button_click' THEN 0 
        ELSE 1 END AS indicator
FROM old
WHERE prev_type IS NOT NULL)

SELECT prev_user AS user_id,
      prev_time AS page_view_time, 
      event_timestamp AS click_time,
      DATEDIFF(second,prev_time, event_timestamp) AS gap_seconds
FROM compare
WHERE indicator = 0
ORDER BY gap_seconds 
LIMIT 1
