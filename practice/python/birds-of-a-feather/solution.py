def partition_by(records, key):
  result = {}
  for r in records:
    k = r[key]
    if k not in result:
      result[k] = []
    result[k].append(r)
  return result    
      
    
    
