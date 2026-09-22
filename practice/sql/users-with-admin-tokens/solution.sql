select user_id, username, email, token_id, scope
from users AS u
inner join api_tokens AS a
ON u.user_id = a.owner_id
where scope like '%admin%'
order by 1 
