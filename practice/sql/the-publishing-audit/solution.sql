select *
FROM content_items
where strftime('%Y',publish_date) = '2026'
