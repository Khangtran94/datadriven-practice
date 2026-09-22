select lower(framework), avg(accuracy)
FROM ml_models
group by 1 order by 2 desc limit 3
