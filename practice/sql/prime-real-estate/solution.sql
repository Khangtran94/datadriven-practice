SELECT device_type, COUNT(*)
FROM devices
WHERE browser = 'Chrome'
GROUP BY 1 
HAVING COUNT(*) >= 2
ORDER BY 2 DESC
