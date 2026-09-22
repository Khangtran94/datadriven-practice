with self AS
(SELECT b1.job_name AS job_1, 
        b1.started AS job1_started,
        b1.ended AS job1_ended,
        b2.job_name AS job_2,
        b2.started AS job2_started,
        b2.ended AS job2_ended
FROM batch_jobs AS b1
JOIN batch_jobs AS b2
ON b1.job_id < b2.job_id 
  AND b1.ended > b2.started 
  AND b1.started < b2.ended)

SELECT COUNT(*) AS min_workers FROM self
  
