SELECT exp_name,
      SUM(CASE WHEN variant = 'control' and outcome > 0 THEN 1 ELSE 0 END) AS control_conversions,
       SUM(CASE WHEN variant = 'treatment' and outcome < 0 THEN 1 ELSE 0 END) as treatment_conversions
FROM experiments
GROUP BY exp_name
