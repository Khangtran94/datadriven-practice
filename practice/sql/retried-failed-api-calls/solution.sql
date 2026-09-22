with next_time AS
(SELECT user_id, endpoint, call_time,
      LAG(call_time) OVER(PARTITION BY user_id, endpoint ORDER BY call_time) AS prev
FROM api_calls
WHERE user_id IS NOT NULL AND err_msg IS NOT NULL
ORDER by 1,2,3),

compare AS
(SELECT *,
    DATEADD(minute, 5, prev) AS next_5_min
FROM next_time
WHERE prev IS NOT NULL 
    AND call_time < next_5_min)

SELECT user_id, endpoint, COUNT(*) AS retry_count
FROM compare 
GROUP BY 1,2 
ORDER BY 3 desc,1,2
