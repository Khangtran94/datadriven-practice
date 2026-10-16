def unique_in_order(items):
  if items:
    total = []  
    for i in items:
      if i not in total:
        total.append(i)
    return total
  return []
