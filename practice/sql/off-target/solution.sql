SELECT
    mdl_name,
    accuracy,
    ROUND(ABS(0.95 - accuracy), 3) AS accuracy_gap
FROM (
    SELECT
        mdl_name,
        accuracy,
        ABS(0.95 - accuracy) AS accuracy_gap,
        PERCENT_RANK() OVER (
            ORDER BY ABS(0.95 - accuracy) DESC
        ) AS pct_rank
    FROM ml_models
    WHERE train_at >= '2026-01-01'
      AND train_at < '2026-07-01'
      AND accuracy IS NOT NULL
) AS ranked
WHERE pct_rank <= 0.10
ORDER BY accuracy_gap DESC
limit 5
