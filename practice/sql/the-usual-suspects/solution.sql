SELECT region, svc_name, COUNT(*) AS check_count
FROM svc_health
WHERE extract(year from checked) = 2025
GROUP BY 1,2
ORDER BY 3 desc
