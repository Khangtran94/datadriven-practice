def paginate(pages: list[list]) -> list:
  total = []
  for p in pages:
    if not p and isinstance(p, list):
      total.extend(paginate(p))
    else:
      total.append(p)
  final = []
  for t in total:
    if isinstance(t, list):
      final.extend(paginate(t))
    else:
      final.append(t)
  return final
