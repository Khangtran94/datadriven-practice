payroll = (employees.groupBy('department').agg(F.sum('salary').alias('total_payroll')))
q1 = (employee_metrics
  .filter(F.col('fiscal_quarter') == 'Q1')
  .groupBy('department')
  .agg(F.sum('metric_value').alias('q1_metric_total')))

payroll.join(q1,payroll['department'] == q1['department'],'left')
  .select(payroll['department'],'total_payroll',coalesce(col('q1_metric_total'),lit(0)).alias('q1_metric_total'))
