SELECT status, count(*)
FROm api_calls
where endpoint = '/api/v1/search'
group by 1 
order by 2 desc
