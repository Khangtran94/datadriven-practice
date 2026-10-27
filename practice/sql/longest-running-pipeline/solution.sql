SELECT DISTINCT pipe_name 
FROM data_pipes 
WHERE dur_secs IN (SELECT max(dur_secs) FROM data_pipes)
