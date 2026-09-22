SELECT strftime('%Y',signup_date) AS signup_year,
     COUNT(*) AS signups, 
     LAG(COUNT(*)) OVER() AS prev_year_signups,
     ROUND(100.0 * (COUNT(*) - LAG(COUNT(*)) OVER()) / LAG(COUNT(*)) OVER()) AS yoy_growth_pct 
FROM users
GROUP BY strftime('%Y',signup_date)
