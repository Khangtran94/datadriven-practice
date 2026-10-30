def flatten(feed: list) -> list:
  total = []
  for f in feed:
    if isinstance(f, list):
      total.extend(flatten(f))
    else:
      total.append(f)
  return total
