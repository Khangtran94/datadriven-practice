import json
import re
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_EVEN
 
PLANS = frozenset({"free", "pro", "team", "enterprise"})
EMAIL_RE = re.compile(r"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}", re.I)
ISO_RE = re.compile(
    r"^(\d{4})-(\d{2})-(\d{2})"
    r"(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?"
    r"(?:\.(\d+))?"
    r"(Z|[+-]\d{2}:?\d{2})?$",
    re.I,
)
US_DATE_RE = re.compile(
    r"^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})"
    r"(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?"
    r"(?:\.(\d+))?"
    r"(Z|[+-]\d{2}:?\d{2})?$",
    re.I,
)
 
 
def _is_blank(v):
    return v is None or (isinstance(v, str) and not v.strip())
 
 
def parse_json_line(raw):
    if raw is None:
        return None
    if isinstance(raw, dict):
        return raw
    if not isinstance(raw, str):
        try:
            raw = raw.decode("utf-8", "ignore") if isinstance(raw, (bytes, bytearray)) else str(raw)
        except Exception:
            return None
    s = raw.strip().lstrip("\ufeff")
    if not s:
        return None
    for candidate in (s,):
        try:
            obj = json.loads(candidate)
            if isinstance(obj, str):
                try:
                    obj = json.loads(obj)
                except Exception:
                    pass
            return obj if isinstance(obj, dict) else None
        except Exception:
            pass
    # Concatenated / trailing junk: take the first {...} span.
    start = s.find("{")
    end = s.rfind("}")
    if start >= 0 and end > start:
        chunk = s[start : end + 1]
        chunk = re.sub(r",\s*([}\]])", r"\1", chunk)
        try:
            obj = json.loads(chunk)
            return obj if isinstance(obj, dict) else None
        except Exception:
            return None
    return None
 
 
def first(*vals):
    for v in vals:
        if not _is_blank(v):
            return v
    return None
 
 
def clean_customer_id(v):
    if _is_blank(v) or isinstance(v, (dict, list, bool)):
        return None
    if isinstance(v, (int, float)):
        if isinstance(v, float) and not v.is_integer():
            return None
        v = str(int(v))
    s = str(v).strip().upper()
    s = re.sub(r"\s+", "", s)
    return s or None
 
 
def clean_email(v):
    if _is_blank(v) or isinstance(v, (dict, list, bool, int, float)):
        return None
    s = str(v).strip()
    if not s:
        return None
    s = re.sub(r"^mailto:", "", s, flags=re.I).strip()
    m = EMAIL_RE.search(s)
    if not m:
        return None
    return m.group(0).lower()
 
 
def _fmt_utc(dt):
    dt = dt.astimezone(timezone.utc).replace(microsecond=0)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
 
 
def _parse_tz(tz):
    if not tz or tz.upper() == "Z":
        return timezone.utc
    sign = 1 if tz[0] == "+" else -1
    digits = tz[1:].replace(":", "")
    hours = int(digits[:2])
    mins = int(digits[2:] or "0")
    from datetime import timedelta
 
    return timezone(sign * timedelta(hours=hours, minutes=mins))
 
 
def _from_parts(y, mo, d, hh=0, mm=0, ss=0, tz=None):
    try:
        y, mo, d = int(y), int(mo), int(d)
        hh = int(hh or 0)
        mm = int(mm or 0)
        ss = int(ss or 0)
        if y < 100:
            y += 2000
        dt = datetime(y, mo, d, hh, mm, ss, tzinfo=_parse_tz(tz))
        return _fmt_utc(dt)
    except Exception:
        return None
 
 
def clean_signup(v):
    if _is_blank(v) or isinstance(v, (dict, list, bool)):
        return None
    if isinstance(v, (int, float)):
        n = float(v)
        if n <= 0:
            return None
        # seconds / ms / us
        if n >= 1e14:
            n /= 1e6
        elif n >= 1e11:
            n /= 1e3
        try:
            dt = datetime.fromtimestamp(n, tz=timezone.utc)
            return _fmt_utc(dt)
        except Exception:
            return None
    s = str(v).strip()
    if s.isdigit() or re.fullmatch(r"\d+\.\d+", s):
        try:
            return clean_signup(float(s) if "." in s else int(s))
        except Exception:
            pass
    m = ISO_RE.match(s)
    if m:
        y, mo, d, hh, mm, ss, _frac, tz = m.groups()
        return _from_parts(y, mo, d, hh, mm, ss, tz)
    m = US_DATE_RE.match(s)
    if m:
        a, b, y, hh, mm, ss, _frac, tz = m.groups()
        a, b = int(a), int(b)
        # US product: ambiguous date is month first.
        if a > 12 and b <= 12:
            day, month = a, b
        else:
            month, day = a, b
        return _from_parts(y, month, day, hh, mm, ss, tz)
    # compact yyyymmdd
    m = re.match(r"^(\d{4})(\d{2})(\d{2})$", s)
    if m:
        return _from_parts(*m.groups())
    return None
 
 
def clean_plan(v):
    if _is_blank(v) or isinstance(v, (dict, list, bool)):
        return None
    s = str(v).strip().lower()
    s = re.sub(r"\s+", " ", s)
    if s in PLANS:
        return s
    tok = re.split(r"[^a-z]+", s)[0] if s else ""
    if tok in PLANS:
        return tok
    return None
 
 
def clean_seats(v):
    if _is_blank(v) or isinstance(v, (dict, list, bool)):
        return None
    if isinstance(v, int):
        return v
    if isinstance(v, float):
        return int(v) if v.is_integer() else None
    s = str(v).strip().replace(",", "")
    try:
        d = Decimal(s)
    except (InvalidOperation, ValueError):
        m = re.search(r"-?\d+", s)
        if not m:
            return None
        try:
            d = Decimal(m.group(0))
        except Exception:
            return None
    if d != d.to_integral_value():
        return None
    return int(d)
 
 
def clean_mrr(v):
    if _is_blank(v) or isinstance(v, (dict, list, bool)):
        return None
    if isinstance(v, str):
        s = v.strip().replace(",", "").replace("$", "")
        if not s:
            return None
        try:
            d = Decimal(s)
        except (InvalidOperation, ValueError):
            return None
    else:
        try:
            d = Decimal(str(v))
        except (InvalidOperation, ValueError):
            return None
    if not d.is_finite():
        return None
    d = d.quantize(Decimal("0.01"), rounding=ROUND_HALF_EVEN)
    return f"{d:.2f}"
 
 
def clean_record(rec):
    cid = clean_customer_id(
        first(
            rec.get("customer_id"),
            rec.get("customerId"),
            rec.get("id"),
        )
    )
    if not cid:
        return None
    return {
        "customer_id": cid,
        "email": clean_email(first(rec.get("email"), rec.get("email_address"))),
        "signup_at": clean_signup(
            first(
                rec.get("signup_ts"),
                rec.get("signup_at"),
                rec.get("signup_date"),
                rec.get("created_at"),
            )
        ),
        "plan": clean_plan(first(rec.get("plan"), rec.get("plan_tier"), rec.get("tier"))),
        "seats": clean_seats(first(rec.get("seats"), rec.get("seat_count"))),
        "mrr_usd": clean_mrr(first(rec.get("mrr"), rec.get("mrr_usd"))),
    }
 
 
class Handler:
    def process(self, raw):
        try:
            rec = parse_json_line(raw)
            if not rec:
                return []
            row = clean_record(rec)
            return [row] if row else []
        except Exception:
            return []
 
    def finalize(self):
        return []
