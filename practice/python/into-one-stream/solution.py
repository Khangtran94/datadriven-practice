def flatten_the_nest(items: list):
  total = []
  for i in items:
    if isinstance(i,list):
      total.extend(flatten_the_nest(i))
    else:
      total.append(i)
  return total
