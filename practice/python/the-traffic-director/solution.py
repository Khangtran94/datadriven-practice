def load_balancer_round_robin(servers: list, requests: list) -> dict:
  new = []
  for i, request in enumerate(requests):
    new.append(servers[i % len(servers)])
  return dict(zip(requests,new))
