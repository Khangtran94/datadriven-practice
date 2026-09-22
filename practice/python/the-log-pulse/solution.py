def count_log_levels(log_lines: list[str]) -> list:
  total = {}
  if not log_lines:
    return [{}, '']
  else:
    for log in log_lines:
      if '[' in log and ']' in log and log.index('[') < log.index(']'):
          level = log[log.index('[') + 1 : log.index(']')].strip()
      else:
          level = 'UNKNOWN'
      total[level] = total.get(level, 0) + 1

    new = sorted(total.items(), key = lambda x:x[1], reverse=True)[0][0]
    return [total, new]
