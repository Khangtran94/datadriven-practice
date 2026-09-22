with total AS
(SELECT user_id, call_time, latency, 
      ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY call_time) AS row_num
FROM api_calls
QUALIFY row_num = 1)

SELECT AVG(latency) AS avg_latency
FROM total
