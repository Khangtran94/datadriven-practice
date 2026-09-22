SELECT svc_name, version, dur_secs, deploy_at
FROm deploy_logs
where dur_secs > 150 and env_name = 'production'
order by 1 desc
