SELECT *,
    duration_seconds::decimal AS duration_decimal,
    (MAX(duration_seconds) OVER () - duration_seconds)::decimal AS diff_from_longest
FROM content_items
ORDER BY duration_seconds DESC, content_id;
