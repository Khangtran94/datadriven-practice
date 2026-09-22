SELECT provider AS provider,
      AVG(CASE WHEN extract(month from bill_date) = 7 THEN amount END) -
      AVG(CASE WHEN extract(month from bill_date) = 1 THEN amount END)  AS amount_chang
FROM cloud_costs
WHERE extract(month from bill_date) IN (1,7)
GROUP BY provider
