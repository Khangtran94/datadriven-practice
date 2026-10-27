SELECT platform, ROUND(AVG(outcome)) AS avg_satisfaction
FROM experiments AS e
INNER JOIN users AS u 
USING (user_id)
WHERE age_bucket = '25-34'
GROUP BY 1
