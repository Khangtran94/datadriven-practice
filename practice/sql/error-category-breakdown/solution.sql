SELECT
  CASE WHEN lower(err_type) LIKE '%timeout%' THEN 'timeout'
      WHEN lower(err_type) LIKE '%memory%' THEN 'memory'
      else 'other' end as error_category,
  COUNT(*) AS track_count
FROM err_tracks
GROUP BY 1
