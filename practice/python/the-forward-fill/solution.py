def forward_fill(values: list) -> list:
  last = None
  for i,v in enumerate(values):
    if v is not None:
      last = v
    else:
      values[i] = last
  return values
