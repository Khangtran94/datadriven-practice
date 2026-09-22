import json
from datetime import datetime, timezone

class Handler:
    customers = {}
    def process(self, raw):
        try:
            record = json.loads(raw)
            #### Normalize the value
                ### customer_id
            customer_id = record.get('customer_id')
            if isinstance(customer_id, str):
                customer_id = customer_id.strip().upper()
                # parts = customer_id.split("-", 1)
                # if (len(parts) == 2 and parts[0] == "C" and len(parts[1]) == 7 and parts[1].isdigit()):
                if (customer_id.startswith('C-') and len(customer_id) == 9 and customer_id[2:].isdigit()):
                    # valid customer_id
                    pass
                else:
                    customer_id = None
            else:
                customer_id = None 
            #### invalid customer_id
            if customer_id is None:
                return []             
                ### signup_ts 
            signup_ts = record.get('signup_ts')
            if isinstance(signup_ts, (int,float)):
                signup_at = datetime.fromtimestamp(signup_ts, tz = timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
            elif isinstance(signup_ts, str):
                ### case string
                try: 
                    dt = datetime.fromisoformat(signup_ts.replace("Z", "+00:00"))
                    signup_at = dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                except ValueError:
                    signup_at = None
            else:
                signup_at = None
                #### plan
            plan = record.get('plan').strip().lower() if isinstance(record.get('plan'),str) else None
                #### seats:
            seats = record.get('seats')
            try:
                seats = int(seats) if seats is not None else None
            except (ValueError, TypeError):
                seats = None
                #### mrr
            mrr = record.get('mrr')
            try:
                mrr_usd = round(float(mrr),2) if mrr is not None else None
            except (ValueError, TypeError):
                mrr_usd = None
                #### each row
            row = {
                "customer_id": customer_id,
                "email": record.get("email").strip().lower() if isinstance(record.get("email"), str) and record.get("email").count('@') == 1 else None,
                "signup_at": signup_at,
                "plan": plan if plan in ['pro','free','team','enterprise'] else None,
                "seats": seats,
                "mrr_usd": mrr_usd
            }
            #### Add latest data:
            Handler.customers[customer_id] = row
            return [row]
        except:
            return []

    def finalize(self):
        return list(Handler.customers.values())
