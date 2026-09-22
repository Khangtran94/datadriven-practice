with each AS
(SELECT svc_name, checked, 
      LAG(status) OVER(PARTITION BY svc_name ORDER BY checked) AS previous_status, 
      status AS current_status
FROM svc_health)

SELECT * FROM each
WHERE previous_status != current_status
