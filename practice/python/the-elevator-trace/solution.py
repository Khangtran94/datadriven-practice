def elevator_path(floors: list[list[int]]) -> list[int]:
  total = [k for i in floors for k in i]
  return total + total[::-1]
