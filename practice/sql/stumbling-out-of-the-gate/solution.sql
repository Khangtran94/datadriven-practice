with total AS
(SELECT mdl_name, version,  
      min(train_at) as very_first, status, accuracy
FROM ml_models
where accuracy is not null
GROUP BY 1,2 order by 2)

SELECT 100.0 * COUNT(*) FILTER(WHERE lower(status) = 'failed') / COUNT(*)
FROM total
where accuracy is not null
