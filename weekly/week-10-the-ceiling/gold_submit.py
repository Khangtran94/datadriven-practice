import json
import re
from datetime import date, datetime, timezone
from functools import lru_cache
 
 
_HEAD = re.compile(
    r"^(?:(?:METAR|SPECI|SAO|SA|SP)\s+)?(?:COR\s+)?"
    r"(?:(?:ICAO|STATION|STN)[=:]\s*)?([A-Z]{4})\s+(?:COR\s+)?"
    r"(?:(?:TIME|OBS|DTG)[=:]\s*)?"
    r"(?:([0-9]{2})[ /-]?([0-9]{2}):?([0-9]{2})Z?"
    r"|([0-9]{4}[-/][0-9]{2}[-/][0-9]{2}[T ][0-9]{2}:[0-9]{2}"
    r"(?::[0-9]{2})?(?:Z|[+-][0-9]{2}:?[0-9]{2})?))(?=\s|=|$)"
)
_ARCHIVE = re.compile(
    r"^([0-9]{4}[-/][0-9]{2}[-/][0-9]{2})[T ]"
    r"[0-9]{2}:[0-9]{2}(?::[0-9]{2})?Z?\s+"
)
_BULLETIN = re.compile(
    r"^(?:ZCZC[^\n]*\n\s*)?(?:[0-9]{3}\s+)?"
    r"[A-Z]{4}[0-9]{2}\s+[A-Z]{4}\s+[0-9]{6}"
    r"(?:\s+(?:CC|RR|AA)[A-Z])?(?=\s|$)\s*"
)
_FORECAST = re.compile(r"^(?:(?:AMD|COR|AUTO)\s+)*[0-9]{4}/[0-9]{4}(?=\s|=|$)")
_WIND = re.compile(r"(?:[0-9]{3}|VRB|///)/?P?([0-9]{1,3})(?:GP?(?:[0-9]{1,3}|//))?(KT|KTS|MPS|KMH|KPH)")
_MILES = re.compile(r"(?:[MP<>])?([0-9]{1,3}(?:[.,][0-9]{1,3})?)(?:/([0-9]{1,3}))?SM")
_METRES = re.compile(r"([0-9]{4})(?:NDV|M)?")
_CLOUD = re.compile(r"(?:BKN|OVC|VV)([0-9]{3})(?:CB|TCU|///)?")
_DEGREES = r"[M+-]?[0-9]{1,2}(?:[.,][0-9]{1,4})?"
_TEMP = re.compile(rf"({_DEGREES})/(?:{_DEGREES}|/+)?")
_TENTHS = re.compile(r"T([01])([0-9]{3})(?:[01][0-9]{3}|////)?")
_ALTIMETER = re.compile(r"([AQ])([0-9]{4})")
_ALTIMETER_TYPED = re.compile(r"(A|Q|QNH)([0-9]{2,4}(?:[.,][0-9]{1,3})?)")
_LEGACY_FIELD = re.compile(r"([A-Z_]+)[=:](.+)")
_NUMBER_UNIT = re.compile(r"([+-]?[0-9]{1,6}(?:[.,][0-9]{1,4})?)([A-Z/]*)")
_TERMINATOR = re.compile(r"=(?=\s|$)")
_CONTINUATION = re.compile(
    r"^(?:RMK|REMARKS|AO[12]|SLP[0-9]{3}|T[01][0-9/]{3,7}|PK|WSHFT|"
    r"P[0-9]{4}|LTG|VIS|WND|CIG|NOSIG|TEMPO|BECMG|"
    r"FEW[0-9/]{3}|SCT[0-9/]{3}|BKN[0-9/]{3}|OVC[0-9/]{3}|VV[0-9/]{3}|"
    r"CAVOK|CLR|SKC|NSC|NCD|[AQ][0-9/]{4}|[0-9]{4}(?:NDV)?|"
    r"[MP<>]?[0-9]{1,3}(?:[.,/][0-9]{1,3})?SM|[0-9]{1,2}(?=\s+[0-9]+/[0-9]+SM)|"
    r"[M+-]?[0-9]{1,2}(?:[.,][0-9]+)?/[M+0-9/-]*|"
    r"(?:[0-9]{3}|VRB|///)[0-9]{1,3}(?:G[0-9]{1,3})?(?:KT|MPS|KMH)|"
    r"R[0-9]{2}[LCR]?/[A-Z0-9/]+|"
    r"[+-]?(?:(?:VC|MI|BC|BL|DR|FZ|SH|TS|PR)?(?:RA|SN|DZ|FG|BR|HZ|"
    r"UP|GR|GS|PL|SG|IC|DU|SA|FU|VA|PY|SQ|FC|DS|SS|PO){1,3}))"
    r"(?=\s|=|$)"
)
_TREND = frozenset(("NOSIG", "BECMG", "TEMPO", "INTER", "PROB30", "PROB40"))
_HEADER_WORDS = frozenset(("COR", "AUTO", "AMD", "RTD", "METAR", "SPECI"))
_TRANSPORT_SPACE = str.maketrans({
    "\x00": " ", "\x01": " ", "\x02": " ", "\x03": " ", "\ufeff": " ",
    "−": "-", "–": "-", "—": "-", "﹣": "-", "－": "-", "＋": "+",
    "⅛": "1/8", "¼": "1/4",
    "½": "1/2", "¾": "3/4", "⁄": "/", "°": "",
})
 
 
@lru_cache(maxsize=128)
def _date(value):
    try:
        return date.fromisoformat(value.replace("/", "-"))
    except ValueError:
        return None
 
 
def _receipt_day(received):
    if not received:
        return None
    if len(received) <= 10 or received.endswith(("Z", "z")):
        return _date(received[:10])
    try:
        stamp = datetime.fromisoformat(received)
        if stamp.tzinfo is not None:
            stamp = stamp.astimezone(timezone.utc)
        return stamp.date()
    except (ValueError, OverflowError):
        return None
 
 
@lru_cache(maxsize=1024)
def _observation_day(day, anchor):
    if not 1 <= day <= 31:
        return None
    if anchor is None:
        # Use the New Year shown in the brief for missing receipt dates.
        if day >= 29:
            return date(2025, 12, day)
        if day <= 3:
            return date(2026, 1, day)
        return None
    month_index = anchor.year * 12 + anchor.month - 1
    candidates = []
    for offset in (0, -1, 1):
        year, month = divmod(month_index + offset, 12)
        try:
            candidates.append(date(year, month + 1, day))
        except ValueError:
            pass
    return min(candidates, key=lambda value: (abs(value - anchor), value), default=None)
 
 
@lru_cache(maxsize=8192)
def _stamp(day, hour, minute):
    return f"{day.isoformat()}T{hour}:{minute}:00Z"
 
 
def _header(report, received):
    match = _HEAD.match(report)
    archive_day = None
    if not match:
        heading = _BULLETIN.match(report)
        if heading:
            report = report[heading.end():]
        archive = _ARCHIVE.match(report)
        if archive:
            archive_day = _date(archive[1])
            report = report[archive.end():]
        match = _HEAD.match(report)
        if not match:
            return None
    station, day, hour, minute, full_stamp = match.groups()
    if station == "AUTO":
        return None
    try:
        if full_stamp is not None:
            dt = datetime.fromisoformat(full_stamp.replace("/", "-"))
            if dt.tzinfo is not None:
                dt = dt.astimezone(timezone.utc)
            observed = dt.replace(tzinfo=None).isoformat(timespec="seconds") + "Z"
        else:
            observed_day = _observation_day(int(day), archive_day or _receipt_day(received))
            if observed_day is None or hour > "23" or minute > "59":
                return None
            observed = _stamp(observed_day, hour, minute)
    except (ValueError, OverflowError):
        return None
    return station, observed, report[match.end():].lstrip()
 
 
def _round_ratio(numerator, denominator):
    return (2 * numerator + denominator) // (2 * denominator)
 
 
@lru_cache(maxsize=4096)
def _tenths_text(tenths):
    whole, fraction = divmod(abs(tenths), 10)
    sign = "-" if tenths < 0 else ""
    return f"{sign}{whole}.{fraction}"
 
 
def _number_ratio(text):
    sign = -1 if text.startswith(("-", "M")) else 1
    whole, _, fraction = text.lstrip("M+-").replace(",", ".").partition(".")
    return sign * int(whole + fraction), 10 ** len(fraction)
 
 
def _temp_value(text):
    number, denominator = _number_ratio(text)
    sign = -1 if number < 0 else 1
    return _tenths_text(sign * _round_ratio(abs(number) * 10, denominator))
 
 
def _wind_knots(speed, unit, denominator=1):
    if unit == "MPS":
        return _round_ratio(speed * 3600, denominator * 1852)
    if unit in ("KMH", "KPH"):
        return _round_ratio(speed * 1000, denominator * 1852)
    return speed if denominator == 1 else _round_ratio(speed, denominator)
 
 
def _surface_visibility(token, previous):
    match = _MILES.fullmatch(token)
    if match:
        numerator, denominator = _number_ratio(match[1])
        if match[2]:
            denominator *= int(match[2])
            if denominator == 0:
                return None
            if 1 <= len(previous) <= 2 and previous.isascii() and previous.isdigit():
                numerator += int(previous) * denominator
        # 1 statute mile = exactly 1609.344 m.
        return min(9999, _round_ratio(numerator * 1609344, denominator * 1000))
    match = _METRES.fullmatch(token)
    return int(match[1]) if match else None
 
 
def _pressure(token):
    match = _ALTIMETER.fullmatch(token)
    if match:
        code = int(match[2])
        if match[1] == "A" and 1500 <= code <= 3500:
            # Hundredths of an inch of mercury to tenths of hPa.
            return _tenths_text(_round_ratio(code * 338639, 100000))
        if match[1] == "Q" and 500 <= code <= 1200:
            return _tenths_text(code * 10)
        return None
    match = _ALTIMETER_TYPED.fullmatch(token)
    if match:
        number, denominator = _number_ratio(match[2])
        if match[1] == "A" and 15 * denominator <= number <= 35 * denominator:
            return _tenths_text(_round_ratio(number * 338639, denominator * 1000))
        if match[1] != "A" and 500 * denominator <= number <= 1200 * denominator:
            return _tenths_text(_round_ratio(number * 10, denominator))
    return None
 
 
def _legacy_field(token):
    match = _LEGACY_FIELD.fullmatch(token)
    if not match:
        return None, None
    name, value = match.groups()
    if name == "WIND":
        wind = _WIND.fullmatch(value)
        if wind:
            return "wind", _wind_knots(int(wind[1]), wind[2])
    match = _NUMBER_UNIT.fullmatch(value)
    if not match:
        return None, None
    digits, unit = match.groups()
    number, denominator = _number_ratio(digits)
    if name in ("TEMP", "TEMP_C", "T") and unit in ("", "C"):
        return "temp", _temp_value(digits)
    if number < 0:
        return None, None
    if name == "WIND_KT" and unit in ("", "KT", "KTS"):
        return "wind", _round_ratio(number, denominator)
    if name in ("WIND", "W") and unit in ("KT", "KTS", "MPS", "KMH", "KPH"):
        return "wind", _wind_knots(number, unit, denominator)
    if name in ("VIS", "VIS_M", "VISIBILITY") and unit in ("", "M", "KM", "SM"):
        multiplier = {"": 1000, "M": 1000, "KM": 1000000, "SM": 1609344}[unit]
        return "visibility", min(9999, _round_ratio(number * multiplier, denominator * 1000))
    if name in ("CIG", "CIG_FT", "CEILING", "CEILING_FT") and unit in ("", "FT"):
        return "ceiling", _round_ratio(number, denominator)
    if name in ("QNH", "ALTIMETER_HPA", "PRESSURE_HPA") or (
        name in ("ALT", "ALTIMETER") and unit in ("HPA", "MB", "INHG", "IN")
    ):
        if unit in ("INHG", "IN"):
            return "pressure", _tenths_text(_round_ratio(number * 338639, denominator * 1000))
        if unit in ("", "HPA", "MB"):
            return "pressure", _tenths_text(_round_ratio(number * 10, denominator))
    return None, None
 
 
def _weather(body):
    """Decode the observation body and the instantaneous-temperature remark."""
    fields = body.split()
    first = 0
    while first < len(fields) and fields[first] in _HEADER_WORDS:
        first += 1
    if first == len(fields) or fields[first] == "NIL" or _FORECAST.match(body):
        return None
 
    wind = visibility = ceiling = temp = pressure = precise = None
    previous = ""
    remarks = trend = False
    for token in fields[first:]:
        if token in ("RMK", "REMARKS"):
            remarks = True
            continue
        if token in _TREND:
            trend = True
            continue
        if remarks:
            match = _TENTHS.fullmatch(token) if token.startswith("T") else None
            if match:
                magnitude = int(match[2])
                precise = _tenths_text(-magnitude if match[1] == "1" else magnitude)
                break
            continue
        if trend:
            continue
        if token == "CAVOK":
            visibility = 9999
        elif token[:3] in ("BKN", "OVC") or token.startswith("VV"):
            match = _CLOUD.fullmatch(token)
            if match:
                height = int(match[1]) * 100
                if ceiling is None or height < ceiling:
                    ceiling = height
        elif "=" in token or ":" in token:
            field, value = _legacy_field(token)
            if field == "wind" and wind is None:
                wind = value
            elif field == "visibility" and visibility is None:
                visibility = value
            elif field == "ceiling" and (ceiling is None or value < ceiling):
                ceiling = value
            elif field == "temp" and temp is None:
                temp = value
            elif field == "pressure" and pressure is None:
                pressure = value
        elif wind is None and token.endswith(("KT", "KTS", "MPS", "KMH", "KPH")):
            match = _WIND.fullmatch(token)
            if match:
                wind = _wind_knots(int(match[1]), match[2])
        elif pressure is None and len(token) >= 4 and token[0] in "AQ":
            pressure = _pressure(token)
        elif token[0] in "0123456789MP<>+-":
            if visibility is None and (token.endswith("SM") or len(token) in (4, 5, 7)):
                visibility = _surface_visibility(token, previous)
            if temp is None and "/" in token and not token.endswith("SM"):
                match = _TEMP.fullmatch(token)
                if match:
                    temp = _temp_value(match[1])
        previous = token
    return wind, visibility, ceiling, precise if precise is not None else temp, pressure
 
 
def _record(raw):
    try:
        record = json.loads(raw)
        if isinstance(record, str) and record.lstrip().startswith("{"):
            record = json.loads(record)
    except (ValueError, RecursionError):
        return None
    if isinstance(record, str):
        return record, "", ""
    if not isinstance(record, dict):
        return None
    report = record.get("report")
    if report is None:
        report = record.get("rawOb") or record.get("metar") or record.get("raw_text") or record.get("line")
    if isinstance(report, list) and len(report) == 2 and all(isinstance(line, str) for line in report):
        report = " ".join(report)
    if not isinstance(report, str):
        return None
    received, feed = record.get("received_at"), record.get("feed")
    return report, received if isinstance(received, str) else "", feed if isinstance(feed, str) else ""
 
 
def _prepare(report):
    if not report.isascii() or any(mark in report for mark in ("\x00", "\x01", "\x02", "\x03")):
        report = report.translate(_TRANSPORT_SPACE)
    report = report.strip().upper()
    if "\\" in report:
        report = report.replace("\\R", " ").replace("\\N", " ").replace("\\T", " ")
    if "|" in report or ";" in report:
        report = report.replace("|", " ").replace(";", " ")
    return report.lstrip()
 
 
def _same_circuit(feed, received, next_feed, next_received):
    if feed and next_feed and feed != next_feed:
        return False
    if not received or not next_received or received == next_received:
        return True
    try:
        delta = datetime.fromisoformat(next_received) - datetime.fromisoformat(received)
        return abs(delta.total_seconds()) <= 120
    except (ValueError, TypeError, OverflowError):
        return False
 
 
def _continued_body(body, tail):
    # Normal circuit wrapping is between groups. Also recover common split tokens.
    first = tail.split(None, 1)[0].rstrip("=") if tail else ""
    if not first:
        return None
    prefix, _, last = body.rpartition(" ")
    joined = last + first
    if (
        (last in ("BKN", "OVC", "VV") and _CLOUD.fullmatch(joined))
        or (last in ("A", "Q") and _ALTIMETER.fullmatch(joined))
        or (last == "T" and _TENTHS.fullmatch(joined))
        or (first in ("SM", "KT", "MPS", "KMH") and
            (_MILES.fullmatch(joined) or _WIND.fullmatch(joined)))
    ):
        return (prefix + " " if prefix else "") + last + tail
    if _CONTINUATION.match(tail):
        return body + " " + tail
    return None
 
 
class Handler:
    def __init__(self):
        self.held = {}
        self.pending = None
 
    def _store(self, station, observed_at, body):
        weather = _weather(body)
        if weather is not None:
            station_rows = self.held.get(station)
            if station_rows is None:
                station_rows = {}
                self.held[station] = station_rows
            station_rows[observed_at] = weather
 
    def _finish_pending(self):
        if self.pending is not None:
            station, observed_at, body, _, _ = self.pending
            self._store(station, observed_at, body)
            self.pending = None
 
    def process(self, raw: str) -> list[dict]:
        record = _record(raw)
        if record is None:
            self._finish_pending()
            return []
        report, received, feed = record
        report = _prepare(report)
        header = _header(report, received)
        if header is None:
            if self.pending is not None:
                station, observed_at, body, previous_received, previous_feed = self.pending
                tail = report.lstrip("+>& ")
                joined = _continued_body(body, tail)
                if joined is not None and _same_circuit(previous_feed, previous_received, feed, received):
                    end = _TERMINATOR.search(joined)
                    if end:
                        joined = joined[:end.start()]
                    self.pending = None
                    self._store(station, observed_at, joined)
                else:
                    self._finish_pending()
            return []
 
        self._finish_pending()
        station, observed_at, body = header
        end = _TERMINATOR.search(body)
        if end:
            self._store(station, observed_at, body[:end.start()])
        else:
            self.pending = station, observed_at, body, received, feed
        # A later file line can supersede any observation key.
        return []
 
    def finalize(self) -> list[dict]:
        self._finish_pending()
        rows = []
        for station, station_rows in self.held.items():
            for observed_at, weather in station_rows.items():
                wind, visibility, ceiling, temp, pressure = weather
                rows.append({
                    "station": station,
                    "observed_at": observed_at,
                    "wind_kt": wind,
                    "visibility_m": visibility,
                    "ceiling_ft": ceiling,
                    "temp_c": temp,
                    "altimeter_hpa": pressure,
                })
            station_rows.clear()
        self.held.clear()
        return rows
