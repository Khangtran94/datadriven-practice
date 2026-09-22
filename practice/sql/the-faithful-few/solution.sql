with each AS
(SELECT user_id, COUNT(DISTINCT device_type) AS unique_device
FROM user_sessions
INNER JOIN devices
USING (device_id)
GROUP BY 1
HAVING unique_device = 1)

SELECT
    d.device_type,
    COUNT(DISTINCT s.user_id) AS exclusive_user_count
FROM user_sessions AS s
INNER JOIN devices AS d
    USING (device_id)
INNER JOIN each AS e
    ON s.user_id = e.user_id
GROUP BY d.device_type
ORDER BY exclusive_user_count DESC;
