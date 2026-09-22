SELECT department, 
      COUNT(*) FILTER(WHERE fiscal_quarter IN ('Q1','Q2')) AS first_half_count,
      COUNT(*) FILTER(WHERE fiscal_quarter IN ('Q3','Q4')) AS second_half_count,
      COUNT(*) FILTER(WHERE fiscal_quarter IN ('Q1','Q2')) / COUNT(*) FILTER(WHERE fiscal_quarter IN ('Q3','Q4')) AS half_year_ratio
FROM employee_metrics
group by department
