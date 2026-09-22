with combine AS
(SELECT
    a.job_id,
    b.job_id,
    a.started,
    a.ended,
    b.started
FROM batch_jobs AS a
INNER JOIN batch_jobs AS b
    ON a.job_id < b.job_id
    AND a.started < b.ended
    AND b.started < a.ended)
 
 SELECT COUNT(*) AS peak FROM combine
