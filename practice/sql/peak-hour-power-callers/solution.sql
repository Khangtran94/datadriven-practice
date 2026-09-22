SELECT user_id, COUNT(*)
FROM api_calls
WHERE extract(hour from call_time) BETWEEN 15 and 17
GROUP BY 1
HAVING COUNT(*) >= 3
ORDeR BY 2 desc
