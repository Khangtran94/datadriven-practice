with total AS
(select date(viewed_at) as view_date, u.user_id, account_status
FROM page_views AS p
inner join users AS u using (user_id)
WHERE account_status IN ('inactive','suspended'))

SELECT view_date, 
      COUNT(*) FILTER(where account_status = 'inactive') AS inactive_views,
      COUNT(*) FILTER(where account_status = 'suspended') AS suspended_views
FROM total
GROUP BY view_date
HAVING COUNT(*) FILTER (WHERE account_status = 'inactive')
     > COUNT(*) FILTER (WHERE account_status = 'suspended');
