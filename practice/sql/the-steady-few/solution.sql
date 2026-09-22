SELECT region, 
    SUM(ROUND(MAX(uptime - (latency / 10),0),2)) AS total_effective
FROM svc_health
GROUP BY 1
QUALIFY DENSE_RANK() OVER(ORDER BY total_effective DESC) < 4
