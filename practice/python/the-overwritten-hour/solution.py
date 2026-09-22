def find_reading(readings, target):
  if target in readings:
    return readings.index(target)
  else:
    return -1
