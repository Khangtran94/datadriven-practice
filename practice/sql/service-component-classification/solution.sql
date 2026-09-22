SELECT DISTINCT svc_name,
   CASE WHEN svc_name LIKE '%/%' THEN 'Multi-Component'
      ELSE 'Single-Component' END AS svc_class
FROM svc_health
