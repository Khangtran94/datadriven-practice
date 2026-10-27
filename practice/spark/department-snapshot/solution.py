(
  employee_metrics
  .groupBy("department")
  .agg(
    F.min("metric_value").alias("min_metric"),
    F.max("metric_value").alias("max_metric"),
    F.round(F.avg("metric_value"), 3).alias("avg_metric"))
  .withColumn("spread",F.col("max_metric") - F.col("min_metric"))
  .orderBy(F.col("spread").desc())
)
