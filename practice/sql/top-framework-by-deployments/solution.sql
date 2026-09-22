SELECT framework
FROM ml_models
WHERE status = 'deployed'
GROUP BY framework
ORDER BY COUNT(*) DESC
LIMIT 1;
