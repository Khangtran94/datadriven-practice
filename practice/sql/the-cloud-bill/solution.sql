SELECT strftime('%Y-%m',bill_date) AS month,
      COALESCE(SUM(CASE WHEN lower(provider) = 'aws' THEN amount END), 0)  AS aws_total,
      COALESCE(SUM(CASE WHEN lower(provider) = 'gcp' THEN amount END), 0) AS gcp_total,
      COALESCE(SUM(CASE WHEN lower(provider) = 'azure' THEN amount END), 0) AS azure_total
FROM cloud_costs
GROUP BY 1
