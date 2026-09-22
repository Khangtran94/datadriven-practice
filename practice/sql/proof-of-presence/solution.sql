with total AS
(SELECT platform AS platform, 
        status AS status, 
        opened
FROM push_notifs
WHERE status = 'delivered')

SELECT platform, 
      ROUND(1.0 * SUM(opened) / COUNT(*),2) AS confirmation_rate
FROM total
GROUP BY platform
