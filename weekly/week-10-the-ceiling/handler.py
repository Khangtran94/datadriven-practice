import json
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP


CANON = ("report", "received_at")
ALIASES = {
    "metar": "report",
    "raw": "report",
    "rawtext": "report",
    "text": "report",
    "message": "report",
    "msg": "report",
    "source": "feed",
    "feedid": "feed",
    "timestamp": "received_at",
    "ts": "received_at",
    "received": "received_at",
    "receivedat": "received_at",
}
CANONICAL_KEY_PRIORITY = {
    "report": ("report", "metar", "raw", "rawtext", "text", "message", "msg"),
    "received_at": ("receivedat", "received", "timestamp", "ts"),
}

KEY_NORM_RE = re.compile(r"[^a-z0-9]+")
HOUR_OFFSET_RE = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})([+-]\d{2})$")
EPOCH_RE = re.compile(r"^\d+$")
WIND_RE = re.compile(
    r"(?:^|\s)(?:[0-9]{3}|VRB)([0-9]{2,3})"
    r"(?:G[0-9]{2,3})?(KT|MPS|KMH)(?:\s|=|$)"
)
ICAO_RE = re.compile(r"^[A-Z]{4}$")
REPORT_TYPE_RE = re.compile(r"^(?:METAR|SPECI)$")
OBSERVATION_TIME_RE = re.compile(r"^\d{6}Z$")
MIXED_SM_RE = re.compile(r"\b(M?)(\d+)\s+(\d+)/(\d+)SM\b")
FRACTION_SM_RE = re.compile(r"\b(M?)(\d+)/(\d+)SM\b")
INTEGER_SM_RE = re.compile(r"\b(M?)(\d+)SM\b")
FIELD_RE = re.compile(
    r'"([^"\\]+)"\s*:\s*'
    r'("(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?|true|false|null)'
    r'\s*(?=,|[}\]])',
    re.I,
)


def norm_key(key):
    return KEY_NORM_RE.sub("", str(key).strip().lower())


def clean_line(line):
    return line.lstrip("\ufeff").strip().replace("\u201c", '"').replace("\u201d", '"')


def rows_from_value(value):
    if isinstance(value, dict):
        for key in ("rows", "records", "items", "messages"):
            nested = value.get(key)
            if isinstance(nested, list):
                if not all(isinstance(item, dict) for item in nested):
                    raise ValueError(f"{key!r} must contain only JSON objects")
                return nested
        return [value]
    if isinstance(value, list):
        if not all(isinstance(item, dict) for item in value):
            raise ValueError("The JSON array must contain only objects")
        return value
    raise ValueError("Expected a JSON object or an array of objects")


def recover_complete_objects(text):
    """Recover complete top-level objects without closing or guessing a tail."""
    decoder = json.JSONDecoder()
    rows = []
    object_depth = 0
    array_depth = 0
    in_string = False
    escaped = False
    index = 0

    while index < len(text):
        char = text[index]

        if (
            not in_string
            and char == "{"
            and object_depth == 0
            and array_depth <= 1
        ):
            try:
                value, end = decoder.raw_decode(text, index)
            except json.JSONDecodeError:
                pass
            else:
                if isinstance(value, dict):
                    rows.append(value)
                    index = end
                    continue

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == "{":
            object_depth += 1
        elif char == "}":
            object_depth = max(0, object_depth - 1)
        elif char == "[":
            array_depth += 1
        elif char == "]":
            array_depth = max(0, array_depth - 1)

        index += 1

    return rows


def salvage_complete_fields(text):
    """Extract only complete JSON key/value pairs from a damaged row."""
    fields = {}
    for match in FIELD_RE.finditer(text):
        key, encoded_value = match.groups()
        try:
            value = json.loads(encoded_value)
        except json.JSONDecodeError:
            continue
        fields.setdefault(key, value)
    return fields


def parse_raw(raw):
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8")
    if not isinstance(raw, str):
        if isinstance(raw, (dict, list)):
            return raw
        raise TypeError("raw must be JSON text, bytes, an object, or an array")

    text = clean_line(raw)
    if not text:
        return None

    value = None
    parse_error = None
    for _ in range(5):
        try:
            value = json.loads(text)
        except json.JSONDecodeError as error:
            parse_error = error
            break
        if not isinstance(value, str):
            return value
        text = value.strip()

    recovered = recover_complete_objects(text)
    if recovered:
        return recovered

    fields = salvage_complete_fields(text)
    if fields:
        return fields
    if parse_error is not None:
        raise ValueError("Invalid JSON; no complete row or fields could be recovered") from parse_error
    raise ValueError("JSON is nested inside too many quoted strings")


def flatten(value, parent="", separator="."):
    """Flatten objects to dotted paths; retain arrays as values."""
    result = {}
    if isinstance(value, dict):
        for key, item in value.items():
            path = f"{parent}{separator}{key}" if parent else str(key)
            if isinstance(item, dict):
                result.update(flatten(item, path, separator))
            else:
                result[path] = item
    else:
        result[parent] = value
    return result


def canonical_key(key):
    normalized = norm_key(str(key).split(".")[-1])
    return ALIASES.get(normalized, normalized)


def to_canonical(value):
    candidates = {}
    for key, item in flatten(value).items():
        name = canonical_key(key)
        if name not in CANON or item in (None, ""):
            continue
        path = str(key)
        candidates.setdefault(name, []).append(
            (norm_key(path.split(".")[-1]), norm_key(path), repr(item), item)
        )

    found = {}
    for name in CANON:
        priority = CANONICAL_KEY_PRIORITY[name]
        options = candidates.get(name, [])
        for preferred_key in priority:
            matches = sorted(
                (option for option in options if option[0] == preferred_key),
                key=lambda option: option[:3],
            )
            if matches:
                found[name] = matches[0][3]
                break
    return {key: found.get(key) for key in CANON}


def clean_report(value):
    if value is None:
        return None
    report = re.sub(r"\s+", " ", str(value)).strip().upper()
    return report[:-1].rstrip() if report.endswith("=") else report


def extract_station(report):
    if report is None:
        return None

    tokens = re.findall(r"[A-Z0-9/]+", str(report).upper())
    if not tokens:
        return None

    for index, token in enumerate(tokens):
        if REPORT_TYPE_RE.fullmatch(token):
            candidate_index = index + 1
            if candidate_index < len(tokens) and tokens[candidate_index] == "COR":
                candidate_index += 1
            if candidate_index < len(tokens):
                candidate = tokens[candidate_index]
                if candidate != "AUTO" and ICAO_RE.fullmatch(candidate):
                    return candidate

    for token in tokens:
        if OBSERVATION_TIME_RE.fullmatch(token):
            break
        if token != "AUTO" and ICAO_RE.fullmatch(token):
            return token
    return None


def clean_timestamp(value):
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None

    if EPOCH_RE.fullmatch(text) and len(text) in (10, 13, 16):
        scale = {10: 1, 13: 1000, 16: 1000000}[len(text)]
        try:
            timestamp = datetime.fromtimestamp(
                int(text) / scale,
                tz=timezone.utc,
            )
        except (OverflowError, OSError, ValueError):
            return None
        return timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")

    hour_offset = HOUR_OFFSET_RE.fullmatch(text)
    if hour_offset:
        text = f"{hour_offset.group(1)}{hour_offset.group(2)}:00"

    try:
        timestamp = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None

    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=timezone.utc)
    else:
        timestamp = timestamp.astimezone(timezone.utc)
    return timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")


def normalize_row(value):
    if not isinstance(value, dict):
        return None
    try:
        row = to_canonical(value)
        report = clean_report(row["report"])
        received_at = clean_timestamp(row["received_at"])
        if report is None or received_at is None:
            return None
        return {
            "report": report,
            "received_at": received_at,
        }
    except (TypeError, ValueError, OverflowError, AttributeError):
        return None


def normalize_rows(raw):
    try:
        value = parse_raw(raw)
        if value is None:
            return []
        rows = rows_from_value(value)
    except (TypeError, ValueError, json.JSONDecodeError, UnicodeDecodeError):
        return []

    normalized = []
    for row in rows:
        try:
            item = normalize_row(row)
        except (TypeError, ValueError, OverflowError, AttributeError):
            continue
        if item is not None:
            normalized.append(item)
    return normalized


def extract_received_at(row):
    if not isinstance(row, dict):
        return None
    return clean_timestamp(row.get("received_at"))


def extract_wind_kt(report):
    """Extract mean wind speed and normalize to knots."""
    if report is None:
        return None

    match = WIND_RE.search(str(report).strip().upper())
    if match is None:
        return None

    try:
        speed = int(match.group(1))
        unit = match.group(2)

        if unit == "KT":
            knots = speed
        elif unit == "MPS":
            knots = speed * 1.94384
        elif unit == "KMH":
            knots = speed / 1.852
        else:
            return None

        return int(knots + 0.5)

    except (TypeError, ValueError):
        return None


def sm_to_meters(value):
    """Convert a statute-mile Decimal value to rounded, capped meters."""
    try:
        meters = value * Decimal("1609.344")
        return min(
            9999,
            int(meters.quantize(Decimal("1"), rounding=ROUND_HALF_UP)),
        )
    except (InvalidOperation, OverflowError, ValueError):
        return None


def extract_visibility_m(report):
    """Extract horizontal visibility as meters; preserve 9999 as visibility >= 10 km."""
    if report is None or not isinstance(report, (str, bytes)):
        return None
    try:
        text = re.sub(r"\s+", " ", str(report).strip()).upper()
        if not text:
            return None

        tokens = text.split()
        if "CAVOK" in tokens:
            return 9999
        if "////" in tokens:
            return None

        after_observation = False
        for token in tokens:
            if OBSERVATION_TIME_RE.fullmatch(token):
                after_observation = True
                continue
            if not after_observation:
                continue
            if token in {"RMK", "NOSIG", "TEMPO", "BECMG"}:
                break
            if re.fullmatch(r"\d{4,5}", token) and not token.startswith("R"):
                meters = int(token)
                if meters >= 0:
                    return min(9999, meters)

        mixed = MIXED_SM_RE.search(text)
        if mixed:
            whole = Decimal(mixed.group(2))
            numerator = Decimal(mixed.group(3))
            denominator = Decimal(mixed.group(4))
            if denominator <= 0:
                return None
            return sm_to_meters(whole + numerator / denominator)

        fraction = FRACTION_SM_RE.search(text)
        if fraction:
            numerator = Decimal(fraction.group(2))
            denominator = Decimal(fraction.group(3))
            if denominator <= 0:
                return None
            return sm_to_meters(numerator / denominator)

        integer = INTEGER_SM_RE.search(text)
        if integer:
            miles = Decimal(integer.group(2))
            return sm_to_meters(miles)
    except (AttributeError, InvalidOperation, OverflowError, TypeError, ValueError):
        return None
    return None


def extract_ceiling_ft(report):
    """Extract the lowest valid BKN, OVC, or VV cloud height in feet."""
    if report is None or not isinstance(report, (str, bytes)):
        return None
    try:
        candidates = []
        text = re.sub(r"\s+", " ", str(report).strip()).upper()

        for token in text.split():
            if token in {"RMK", "NOSIG", "TEMPO", "BECMG"}:
                break
            match = re.fullmatch(r"(BKN|OVC|VV)(\d{3})(?:[A-Z]+)?", token)
            if match is None:
                continue
            candidates.append(int(match.group(2)) * 100)

        return min(candidates) if candidates else None
    except (AttributeError, OverflowError, TypeError, ValueError):
        return None


def extract_temp_c(report):
    """Extract air temperature in Celsius with exactly one decimal place."""
    if report is None or not isinstance(report, (str, bytes)):
        return None
    try:
        text = re.sub(r"\s+", " ", str(report).strip()).upper()
        if not text:
            return None

        rmk_match = re.search(r"\bRMK\b", text)
        if rmk_match:
            rmk_text = text[rmk_match.end():]
            precision_match = re.search(r"\bT([01])(\d{3})([01])(\d{3})\b", rmk_text)
            if precision_match:
                tenths = int(precision_match.group(2))
                temperature = -tenths if precision_match.group(1) == "1" and tenths != 0 else tenths
                sign = "-" if temperature < 0 else ""
                magnitude = abs(temperature)
                return f"{sign}{magnitude // 10}.{magnitude % 10}"

        body = text[:rmk_match.start()] if rmk_match else text
        standard_match = re.search(r"\b(M?\d{2})/(M?\d{2})\b", body)
        if standard_match:
            temperature_text = standard_match.group(1)
            negative = temperature_text.startswith("M")
            digits = temperature_text[1:] if negative else temperature_text
            temperature = int(digits)
            if negative and temperature != 0:
                temperature = -temperature
            return f"{temperature:.1f}"
    except (AttributeError, OverflowError, TypeError, ValueError):
        return None
    return None


def extract_altimeter_hpa(report):
    """Extract an A-group or Q-group altimeter setting in hPa."""
    if report is None or not isinstance(report, (str, bytes)):
        return None

    try:
        text = re.sub(r"\s+", " ", str(report).strip()).upper()
        if not text:
            return None

        rmk_match = re.search(r"\bRMK\b", text)
        body = text[:rmk_match.start()] if rmk_match else text

        a_match = re.search(r"\bA(\d{4})\b", body)
        if a_match:
            inhg = Decimal(a_match.group(1)) / Decimal("100")
            if not Decimal("28.0") <= inhg <= Decimal("32.0"):
                return None
            hpa = (inhg * Decimal("33.8639")).quantize(
                Decimal("0.1"),
                rounding=ROUND_HALF_UP,
            )
            return format(hpa, ".1f")

        q_match = re.search(r"\bQ(\d{4})\b", body)
        if q_match:
            hpa = Decimal(q_match.group(1))
            if not Decimal("850") <= hpa <= Decimal("1100"):
                return None
            hpa = hpa.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP)
            return format(hpa, ".1f")
    except (AttributeError, InvalidOperation, OverflowError, TypeError, ValueError):
        return None
    return None


def extract_observed_at(report, received_at):
    """Extract a minute-precision METAR observation time closest to received_at."""
    if report is None or received_at is None:
        return None

    text = re.sub(r"\s+", " ", str(report).strip()).upper()
    rmk_match = re.search(r"\bRMK\b", text)
    body = text[:rmk_match.start()] if rmk_match else text
    timestamp_match = re.search(r"\b(\d{2})(\d{2})(\d{2})Z\b", body)
    if timestamp_match is None:
        return None

    try:
        day = int(timestamp_match.group(1))
        hour = int(timestamp_match.group(2))
        minute = int(timestamp_match.group(3))
        if hour > 23 or minute > 59:
            return None
    except (TypeError, ValueError):
        return None

    normalized_received = clean_timestamp(received_at)
    if normalized_received is None:
        return None
    try:
        reference = datetime.strptime(
            normalized_received,
            "%Y-%m-%dT%H:%M:%SZ",
        ).replace(tzinfo=timezone.utc)
    except (TypeError, ValueError):
        return None

    candidates = []
    for month_offset in (-1, 0, 1):
        month_index = reference.year * 12 + (reference.month - 1) + month_offset
        year = month_index // 12
        month = month_index - year * 12 + 1
        try:
            candidate = datetime(
                year,
                month,
                day,
                hour,
                minute,
                0,
                tzinfo=timezone.utc,
            )
        except (TypeError, ValueError):
            continue
        candidates.append(candidate)

    if not candidates:
        return None

    selected = min(
        candidates,
        key=lambda candidate: (
            abs((candidate - reference).total_seconds()),
            candidate,
        ),
    )
    return selected.strftime("%Y-%m-%dT%H:%M:%SZ")


def extract_columns(rows):
    """Aggregate all child METAR column extractors for one normalized record."""
    output = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        station = extract_station(row.get("report"))
        received_at = extract_received_at(row)
        observed_at = extract_observed_at(row.get("report"), received_at)
        if station is None or received_at is None or observed_at is None:
            continue
        output.append({
            "station": station,
            "observed_at": observed_at,
            "wind_kt": extract_wind_kt(row.get("report")),
            "visibility_m": extract_visibility_m(row.get("report")),
            "ceiling_ft": extract_ceiling_ft(row.get("report")),
            "temp_c": extract_temp_c(row.get("report")),
            "altimeter_hpa": extract_altimeter_hpa(row.get("report")),
        })
    return output


def deduplicate_records(rows):
    """Apply last-write-wins in stream order by (station, observed_at)."""
    records_map = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        station = row.get("station")
        observed_at = row.get("observed_at")
        if station is None or observed_at is None:
            continue
        records_map[(station, observed_at)] = row
    return list(records_map.values())


def _record_key(row):
    station = row.get("station")
    observed_at = row.get("observed_at")
    if station is None or observed_at is None:
        return None
    return f"{station}|{observed_at}"


def _pack_record(row):
    return (
        row.get("wind_kt"),
        row.get("visibility_m"),
        row.get("ceiling_ft"),
        row.get("temp_c"),
        row.get("altimeter_hpa"),
    )


def _unpack_record(key, values):
    station, _, observed_at = key.partition("|")
    return {
        "station": station,
        "observed_at": observed_at,
        "wind_kt": values[0],
        "visibility_m": values[1],
        "ceiling_ft": values[2],
        "temp_c": values[3],
        "altimeter_hpa": values[4],
    }


class Handler:
    def __init__(self):
        self.output_rows = None
        self.records_map = {}

    def process(self, raw):
        try:
            rows = normalize_rows(raw)
            extracted = extract_columns(rows)
        except (TypeError, ValueError, KeyError, AttributeError, OverflowError, OSError):
            return []

        out = []
        for row in extracted:
            if not isinstance(row, dict):
                continue
            key = _record_key(row)
            if key is None:
                continue
            values = _pack_record(row)
            if self.records_map.get(key) == values:
                continue
            self.records_map[key] = values
            out.append(row)
        return out

    def extract_columns(self, rows=None):
        if rows is None:
            return [
                _unpack_record(key, values)
                for key, values in self.records_map.items()
            ]
        self.output_rows = extract_columns(rows)
        return list(self.output_rows)

    def deduplicate(self, rows=None):
        source = self.output_rows if rows is None else rows
        if source is None:
            return self.extract_columns()

        for row in source:
            if not isinstance(row, dict):
                continue
            key = _record_key(row)
            if key is None:
                continue
            self.records_map[key] = _pack_record(row)
        return self.extract_columns()

    def finalize(self):
        return []
