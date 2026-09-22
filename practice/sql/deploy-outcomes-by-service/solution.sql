select svc_name, 
      COALESCE(SUM(CAse when lower(status) = 'success' then 1 end),0) as success_count,
      COALESCE(SUM(CAse when lower(status) = 'failed' then 1 end),0) as failed_count,
      COALESCE(SUM(CAse when lower(status) = 'rolled_back' then 1 end),0) as rolled_back_count
FROM deploy_logs
GROUP BY 1
order by 1
