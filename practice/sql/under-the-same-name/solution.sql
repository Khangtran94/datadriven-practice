SELECT lower(status), avg(latency)
FROm svc_health
GROUP BY 1 
order by 2 desc
