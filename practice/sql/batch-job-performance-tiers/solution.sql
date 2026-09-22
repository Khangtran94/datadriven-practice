SELECT job_name, SUM(rows_done) AS total_rows,
      case when sum(rows_done) >= 30000 THEN 'Outstanding'
          when sum(rows_done) >= 20000 THEN 'Satisfactory'
          when sum(rows_done) >= 10000 then 'Unsatisfactory'
          else 'poor' end as performance_tier
FROM batch_jobs
GROUP BY 1 order by 2 desc
