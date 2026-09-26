def kth_missing(ids, k):
  begin = ids[0]
  end = ids[-1]
  new = [i for i in range(begin,end+1) if i not in ids]
  if not new:
    return end + k
  if k <= len(new):
    return new[k-1]
  else:
    return end + (k - len(new))
