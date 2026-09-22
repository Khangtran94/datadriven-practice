(dq_checks
  .groupBy('tbl_name')
  .agg(F.avg('fail_pct').alias('avg_fail_pct'))
  .orderBy('avg_fail_pct'))
