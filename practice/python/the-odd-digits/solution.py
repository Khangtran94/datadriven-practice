def extract_odd_from_string(s: str) -> str:
  total = []
  for i in s:
    if i.isdigit() and int(i) % 2 != 0:
      total.append(i)
  return ''.join(total)
