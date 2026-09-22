SELECT svc_name, ROUND(AVG(uptime),2) AS avg_uptime, 
      DENSE_RANK() OVER(ORDER BY AVG(uptime) DESC) AS rank
FROM svc_health
GROUP BY svc_name 
HAVING COUNT(*) >= 5
QUALIFY rank < 4
