def coalesce(primary: dict, defaults: dict) -> dict:
  check = {}
  for k,v in primary.items():
    if v is None and k in defaults:
      check[k] = defaults[k]
    else:
      check[k] = v
  return check
