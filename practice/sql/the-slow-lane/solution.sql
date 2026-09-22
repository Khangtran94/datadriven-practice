SELECT endpoint, max(latency)
FROm api_calls
WHERE strftime('%m', call_time) = '03'
group by 1 order by 2 desc
