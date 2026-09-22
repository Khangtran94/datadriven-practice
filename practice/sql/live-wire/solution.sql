select owner, flag_name, max(updated) AS last_changed
FROM feat_flags
group by 1
