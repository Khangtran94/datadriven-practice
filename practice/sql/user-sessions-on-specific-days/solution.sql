select *
FROM user_sessions
where user_id = 197 and extract(dow from session_start) in (1,6)
