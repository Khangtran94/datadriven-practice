select extract(year from publish_date), COUNT(*), avg(duration_seconds)
FROM content_items
where publish_date is not null
GROUP by 1
order by 1
