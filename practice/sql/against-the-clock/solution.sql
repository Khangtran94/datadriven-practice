SELECT job_id, 
    job_name, 
      CAST((JULIANDAY(ended) - JULIANDAY(started)) * 1440 AS integer) AS test
FROM batch_jobs
WHERE ended IS NOT NULL AND ended > started
