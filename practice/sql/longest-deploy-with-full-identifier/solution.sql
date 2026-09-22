with longest AS
(SELECT * FROM deploy_logs WHERE dur_secs IN (SELECT MAX(dur_secs) FROM deploy_logs))

SELECT CONCAT(svc_name,':',version,' (deploy #',log_id,')') AS full_identifier,
      dur_secs 
FROM longest
