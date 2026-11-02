def flatten_generator(nested: list) -> list:
  total = []
  for n in nested:
    if isinstance(n,list):
      total.extend(flatten_generator(n))
    else:
      total.append(n)
  return total
