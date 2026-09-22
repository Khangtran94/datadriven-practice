(cloud_costs
  .filter((F.col('amount') >= 200) & (F.lower(F.col('provider') == 'aws')))
  .agg(F.countDistinct('svc_name').alias('service_count')))
