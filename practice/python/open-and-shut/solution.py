def is_balanced(s: str) -> bool:
  bracket = {')':'(', ']':'[', '}':'{'}
  total = []
  for ch in s:
    if ch in "([{":
      total.append(ch)
    elif ch in ")]}":
      if not total or total.pop() != bracket[ch]:
        return False
  return not total
