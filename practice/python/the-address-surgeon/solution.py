def parse_address(address):
  text = [p.strip() for p in address.split(',')]
  state, code = text[2].split(' ')[0], text[2].split(' ')[1]
  city = text[1]
  street = text[0]
  return {"street":street,"city":city,"state":state,"zip":str(code)}
