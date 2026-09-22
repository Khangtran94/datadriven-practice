SELECT *, ROW_NUMBER() OVER() AS rn
FROM page_views
QUALIFY rn <= (SELECT COUNT(*) / 2 FROM page_views)
