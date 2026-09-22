def remove_consecutive_dupes(items):
  new = []
  for i in range(len(items) - 1):
    if items[i] != items[i+1]:
      new.append(items[i])
  if items:
    new.append(items[-1])
  return new
