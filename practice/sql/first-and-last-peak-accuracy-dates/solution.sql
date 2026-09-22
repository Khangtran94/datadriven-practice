with top1 AS
(SELECT max(accuracy) AS accuracy
FROM ml_models)

SELECT MIN(train_at) AS first_date,
      MAX(train_at) AS last_date
FROM ml_models
WHERE accuracy IN (SELECT accuracy FROM top1)
