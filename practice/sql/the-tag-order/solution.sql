SELECT event_id, LOWER(tags) AS normalized_tags
FROM event_data
WHERE event_type ='signup'
