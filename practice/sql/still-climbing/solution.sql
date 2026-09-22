with mar AS
(SELECT svc_name, status, checked
FROM svc_health
WHERE strftime('%Y-%m',checked) IN ('2026-02','2026-03')),

growth AS
(SELECT svc_name, 
      SUM(CASE WHEN strftime('%Y-%m',checked) = '2026-02' THEN 1 END) AS feb,
      SUM(CASE WHEN strftime('%Y-%m',checked) = '2026-03' THEN 1 END) AS march
FROM mar
GROUP BY svc_name)

SELECT svc_name, 
     round(1.0 * coalesce(march,0) / feb,3) as growth_rate
FROM growth
