SELECT page_url, COUNT(*)
FROM page_views
group by 1 order by 2 desc
