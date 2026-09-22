with calculate AS
(SELECT bill_date, svc_name, SUM(amount) AS total_amount
FROM cloud_costs
GROUP BY bill_date, svc_name
ORDER BY bill_date, total_amount DESC),

fill_rank AS
(SELECT *, ROW_NUMBER() OVER(PARTITION BY bill_date ORDER BY total_amount DESC) AS rnk
FROM calculate),

prev AS
(SELECT bill_date, svc_name, total_amount,
       LAG(svc_name) OVER(ORDER BY bill_date) AS prev_svc,
       LAG(total_amount) OVER(ORDER BY bill_date) AS prev_amount
FROM fill_rank
WHERE rnk = 1)

SELECT bill_date, prev_svc AS svc_name, prev_amount AS total_amount
FROM prev
WHERE prev_svc IS NOT NULL
