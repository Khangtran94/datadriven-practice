(
cloud_costs
  .filter(F.col('acct_id').isNotNull())
  .withColumn('provider',F.upper('provider'))
  .groupBy('provider')
  .agg(F.max('amount').alias('max_amount'))
)
