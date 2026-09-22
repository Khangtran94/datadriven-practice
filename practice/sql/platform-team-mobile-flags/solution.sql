SELECT owner, flag_name 
FROM feat_flags
WHERE owner = 'platform' and flag_name ILIKE '%mobile%'
