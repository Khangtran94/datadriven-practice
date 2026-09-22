SELECT endpoint, MAX(latency) AS rarest_highest
FROM api_calls
GROUP BY 1
order by 2 desc
