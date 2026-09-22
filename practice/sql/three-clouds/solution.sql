SELECT amount 
FROM cloud_costs
WHERE LOWER(provider) IN (
  'aws',
  'gcp',
  'azure'
  )ORDER BY amount
