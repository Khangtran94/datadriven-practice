(
employees
  .filter(col('user_id').isNotNull())
  .groupBy('department')
  .agg(F.count("*").alias('linked_employees'))
  .orderBy(F.col('linked_employees').desc())
)
