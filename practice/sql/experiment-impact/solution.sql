with summarize AS
(SELECT exp_name, variant, 
       AVG(outcome) AS avg_out, 
       COUNT(user_id) AS participants
FROM experiments
WHERE outcome IS NOT NULL
GROUP BY 1,2
ORDER BY 3 desc)

SELECT *, 
      RANK() OVER(PARTITION BY variant ORDER BY avg_out DESC) AS rnk,
      DENSE_RANK() OVER(PARTITION BY variant ORDER BY avg_out DESC) AS tier
FROM summarize
