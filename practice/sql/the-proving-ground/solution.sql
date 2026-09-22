SELECT lower(framework), AVG(accuracy)
FROM ml_models
WHERE extract(year from train_at) = 2026
GROUP BY 1 
order by 2 desc
