(
employee_metrics
  .select('metric_value').distinct()
  .orderBy(F.col('metric_value').desc())
  .limit(5)
)
