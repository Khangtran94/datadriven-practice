def filter_integers(items: list) -> list[int]:
  return [i for i in items if isinstance(i,int) and not(isinstance(i,bool))]
