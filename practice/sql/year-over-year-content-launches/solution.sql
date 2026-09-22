select creator_id,
     SUM(case when extract(year from publish_date) = 2026 THEN 1 else 0 END) - 
      SUM(case when extract(year from publish_date) = 2025 THEN 1 else 0 END) AS net_diff
FROM content_items
WHERE STRFTIME('%Y', publish_date) IN (
  '2025',
  '2026'
  )
GROUP By 1
order by 2 desc,1
