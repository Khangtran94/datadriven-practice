def dedup_preserve_order(items: list) -> list:
  total = []
  for i in items:
    if i not in total:
      total.append(i)
  return total
