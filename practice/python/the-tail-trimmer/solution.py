def remove_kth_from_end(lst: list, k: int) -> list:
  if k > len(lst):
    return lst
  index = len(lst) - k
  lst.pop(index)
  return lst
