SELECT device_type, os_name, COUNT(*)
FROM devices
GROUP BY 1, 2
