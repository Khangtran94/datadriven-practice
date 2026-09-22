SELECT SUBSTRING(bill_date,1,4) AS fiscal_year,
      SUM(amount) As total_spend,
      COUNT(DISTINCT svc_name) AS service_count
FROM cloud_costs
GROUP BY fiscal_year
ORDER BY fiscal_year
