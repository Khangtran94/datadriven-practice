def the_deep_dive(counts: dict[str, int], n: int):
  new = sorted(list(set(counts.values())),reverse=True)
  if n <= len(new):
    return new[n-1]
  else:
    return None
