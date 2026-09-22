SELECT svc_name, bill_date, amount,
      amount - LAG(amount) OVER(PARTITION BY svc_name ORDER BY bill_date) AS price_change
FROM cloud_costs
ORDER BY svc_name, bill_date
