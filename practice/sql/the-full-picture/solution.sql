(
    employees
    .join(employee_metrics, "department", "left")
    .groupBy("employee_id", "emp_name")
    .agg(
        F.coalesce(
            F.sum("metric_value"),
            F.lit(0)
        ).alias("total_metric_value")
    )
    .select("emp_name", "total_metric_value")
)
