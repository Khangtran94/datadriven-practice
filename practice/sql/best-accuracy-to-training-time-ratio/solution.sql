select mdl_name, accuracy, train_at, 
      accuracy / cast(STRFTIME('%s', train_at) AS REAL) AS ratio
fROM ml_models
where accuracy is not null
order by 4 desc
limit 1
