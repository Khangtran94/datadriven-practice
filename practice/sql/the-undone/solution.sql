select db_name, COUNT(*) AS total_migrations, 
      SUM(CASE WHEN status = 'rolled_back' then 1 else 0 end) AS total_rollbacks
FROM migrations
GROUP BY 1 
order by 3 desc
