def aggregate_trades(lines: list[str]) -> list:
  bytes = {}
  hosts = {}
  if not lines:
    return [{},{}]
  
  for l in lines:
    row = l.split(',')
    day, byte, host = row[0],int(row[-1]),row[1].split('_')[0]
    bytes[day] = bytes.get(day,0) + byte
    if day not in hosts:
      hosts[day] = {}
    hosts[day][host] = hosts[day].get(host,0) + byte
  return [bytes,hosts]
