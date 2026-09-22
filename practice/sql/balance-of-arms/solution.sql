SELECT exp_name,
      COUNT(DISTINCT CASE WHEN variant = 'control' THEN user_id END) AS control_users,
      COUNT(DISTINCT CASE WHEN variant != 'control'  THEN user_id END) AS treatment_users,
      ROUND(1.0 * COUNT(DISTINCT CASE WHEN variant != 'control'  THEN user_id END) / COUNT(DISTINCT CASE WHEN variant = 'control' THEN user_id END),3) AS treatment_to_control_ratio
FROM experiments
GROUP BY exp_name
