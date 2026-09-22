def longest_hold(readings):
  current = 1
  total = []

  if len(readings) == 0:
    return 0

  for i in range(len(readings) - 1):
    if readings[i] <= readings[i + 1]:
      current += 1
    else:
      total.append(current)
      current = 1

  total.append(current)

  return max(total)
