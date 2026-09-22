with total AS
(SELECT svc_name, extract(month from bill_date) AS mth,
      extract(quarter from bill_date) AS q,
      SUM(amount) AS spend
FROM cloud_costs
GROUP BY svc_name, 2,3),

rownum AS
(SELECT *,
      ROW_NUMBER() OVER(PARTITION BY svc_name,q ORDER BY spend DESC) AS rnk
FROM total)

SELECT svc_name, 
      MAX(CASE WHEN q = 1 AND rnk = 1 THEN spend END) AS q1_max,
      MAX(CASE WHEN q = 2 AND rnk = 1 THEN spend END) AS q2_max,
      MAX(CASE WHEN q = 3 AND rnk = 1 THEN spend END) AS q3_max,
      MAX(CASE WHEN q = 4 AND rnk = 1 THEN spend END) AS q4_max
FROM rownum
GROUP BY svc_name
-- SELECT * FROM rownum
