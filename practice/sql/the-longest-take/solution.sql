SELECT DISTINCT
  ci.content_id,
  ci.title
FROM content_items AS ci
WHERE ci.duration_seconds = (
  SELECT
    MAX(ci2.duration_seconds)
  FROM content_items AS ci2
  WHERE ci2.content_type = ci.content_type
)
AND ci.publish_date >= '2026-01-01'
ORDER BY ci.content_id
