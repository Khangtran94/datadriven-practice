(content_items
  .select('content_id','title','duration_seconds')
  .orderBy('duration_seconds',ascending = False))
