SELECT upper(provider) AS provider,
     MAX(amount) AS max_amount
FROM cloud_costs
WHERE acct_id IS NOT NULL
GROUP BY 1
