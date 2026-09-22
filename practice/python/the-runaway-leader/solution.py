def dominant_element(readings: list[int]):
    check = len(readings) / 2
    from collections import Counter
    count = dict(Counter(readings))
    for i,v in count.items():
      if v > check:
        return i
