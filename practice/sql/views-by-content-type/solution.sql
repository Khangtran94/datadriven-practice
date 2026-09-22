SELECT content_type, COUNT(view_id)
FRom content_items
INNER JOIN content_views 
USING (content_id)
GROUP BY 1
