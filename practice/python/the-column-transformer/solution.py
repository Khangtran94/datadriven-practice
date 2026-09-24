def apply_transforms(rows: list, transforms: dict) -> list:
  func = {'upper':lambda x: x.upper(),'lower':lambda x:x.lower(),'increment':lambda x:x+1,'double':lambda x:x*2}
  for r in rows:
    for c,f in transforms.items():
      if c in r.keys():
        r[c] = func[f](r[c])
  return rows
