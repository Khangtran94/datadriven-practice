# Week 10 – The Ceiling: Giải thích toàn bộ `handler.py` cho người mới học Python

**Đối tượng đọc:** Người đã biết sơ bộ `def`, `for`, `if`, nhưng chưa quen các khái niệm Python nâng cao.

**File phân tích:** `weekly/week-10-the-ceiling/handler.py` trong repository `Khangtran94/datadriven-practice`.

---

# 1. Hiểu bài toán trước khi đọc code

Week 10 yêu cầu biến log chứa các báo cáo thời tiết hàng không METAR thành bảng dữ liệu sạch.

Ví dụ một METAR:

```text
METAR EGLL 312050Z 24012KT 9999 FEW020 12/08 Q1013=
```

Ý nghĩa các phần chính:

| Nội dung | Ý nghĩa |
|---|---|
| `METAR` | Loại báo cáo |
| `EGLL` | Mã sân bay ICAO |
| `312050Z` | Ngày 31, 20:50 UTC; chưa có tháng/năm |
| `24012KT` | Gió 240 độ, tốc độ 12 knots |
| `9999` | Tầm nhìn từ 10 km trở lên |
| `FEW020` | Mây FEW ở độ cao 2.000 feet |
| `12/08` | Nhiệt độ 12°C, điểm sương 8°C |
| `Q1013` | Áp suất 1013 hPa |
| `=` | Ký tự kết thúc báo cáo |

Đầu ra cần có các trường:

- `station`: mã sân bay.
- `observed_at`: thời điểm quan sát thực tế.
- `wind_kt`: tốc độ gió, knots.
- `visibility_m`: tầm nhìn, mét.
- `ceiling_ft`: trần mây, feet.
- `temp_c`: nhiệt độ Celsius.
- `altimeter_hpa`: áp suất hPa.

Hai thời điểm cần phân biệt:

- `received_at`: lúc hệ thống nhận được báo cáo.
- `observed_at`: lúc sân bay thực sự quan sát thời tiết.

Báo cáo có thể được gửi muộn sau khi mất kết nối. METAR chỉ ghi ngày trong tháng và giờ, nên code phải dùng `received_at` làm ngữ cảnh để suy ra tháng/năm cho `observed_at`.

---

# 2. Các thư viện và biến cấu hình đầu file

## 2.1. `import` là gì?

`import` đưa thư viện vào để sử dụng.

```python
import json
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
```

| Thư viện | Vai trò |
|---|---|
| `json` | Đọc dữ liệu JSON |
| `re` | Regex: tìm mẫu trong chuỗi |
| `datetime` | Xử lý ngày giờ |
| `timedelta` | Khoảng thời gian; được import nhưng không thấy sử dụng trong file này |
| `timezone` | Múi giờ, đặc biệt UTC |
| `Decimal` | Tính số thập phân chính xác hơn `float` trong các phép tính tài chính/đơn vị |
| `InvalidOperation` | Lỗi khi phép tính Decimal không hợp lệ |
| `ROUND_HALF_UP` | Làm tròn kiểu thông thường, phần .5 làm tròn lên |

## 2.2. Các biến cấu hình

```python
CANON = ("report", "received_at")
```

`CANON` là danh sách tên trường chuẩn (thực tế là tuple). Dù đầu vào gọi báo cáo là `metar`, `raw`, `msg`..., sau chuẩn hóa code muốn có hai trường `report` và `received_at`.

```python
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
```

Đây là dictionary, tức cấu trúc lưu cặp `key: value`. Ví dụ `"metar": "report"` nghĩa là key `metar` được coi là `report`.

`source` và `feedid` được đổi thành `feed`, nhưng `feed` không nằm trong `CANON`, vì vậy không phải trường chuẩn cuối cùng mà code giữ lại.

```python
CANONICAL_KEY_PRIORITY = {
    "report": ("report", "metar", "raw", "rawtext", "text", "message", "msg"),
    "received_at": ("receivedat", "received", "timestamp", "ts"),
}
```

Nếu một record có nhiều key cùng đại diện cho một trường, dictionary này quyết định key nào được ưu tiên. Ví dụ `report` được ưu tiên hơn `metar`, `raw`.

## 2.3. Regex được khai báo ở đầu file

Ví dụ:

```python
KEY_NORM_RE = re.compile(r"[^a-z0-9]+")
ICAO_RE = re.compile(r"^[A-Z]{4}$")
EPOCH_RE = re.compile(r"^\d+$")
```

Regex là cách mô tả một mẫu văn bản.

- `a-z`: chữ thường.
- `A-Z`: chữ hoa.
- `0-9` hoặc `\d`: chữ số.
- `^`: đầu chuỗi.
- `$`: cuối chuỗi.
- `+`: một hoặc nhiều lần.
- `{4}`: đúng 4 lần.
- `[^...]`: ký tự không thuộc nhóm trong ngoặc vuông.
- `\s`: khoảng trắng.
- `\b`: ranh giới từ.
- `?`: phần trước đó có thể xuất hiện hoặc không.

Một số regex chính:

| Biến | Công việc |
|---|---|
| `KEY_NORM_RE` | Loại dấu cách, dấu gạch, dấu gạch dưới khỏi key |
| `HOUR_OFFSET_RE` | Nhận timestamp có timezone chỉ ghi `+07`, thay vì `+07:00` |
| `EPOCH_RE` | Kiểm tra chuỗi chỉ gồm chữ số |
| `WIND_RE` | Tìm nhóm tốc độ gió |
| `ICAO_RE` | Kiểm tra mã sân bay 4 chữ cái in hoa |
| `REPORT_TYPE_RE` | Tìm `METAR` hoặc `SPECI` |
| `OBSERVATION_TIME_RE` | Nhận dạng giờ quan sát 6 chữ số kết thúc bằng Z |
| `MIXED_SM_RE` | Tầm nhìn hỗn hợp, ví dụ `1 1/2SM` |
| `FRACTION_SM_RE` | Tầm nhìn phân số, ví dụ `1/2SM` |
| `INTEGER_SM_RE` | Tầm nhìn số nguyên, ví dụ `10SM` |
| `FIELD_RE` | Tìm cặp key/value JSON hoàn chỉnh trong dữ liệu bị hỏng |

### `search`, `match`, `fullmatch` khác nhau

- `search`: tìm ở bất kỳ vị trí nào.
- `match`: kiểm tra từ đầu chuỗi.
- `fullmatch`: yêu cầu toàn bộ chuỗi khớp mẫu.

Ví dụ:

```python
re.search(r"\d+", "ABC123")       # tìm thấy 123
re.match(r"\d+", "ABC123")        # không khớp vì chuỗi không bắt đầu bằng số
re.fullmatch(r"\d+", "123")       # khớp toàn bộ chuỗi
re.fullmatch(r"\d+", "123ABC")    # không khớp
```

---

# 3. Nhóm đọc và cứu dữ liệu JSON

Đây là bước đầu pipeline: dữ liệu có thể là JSON bình thường, JSON bị encode nhiều lớp hoặc JSON hỏng một phần.

## 3.1. `norm_key(key)`

```python
def norm_key(key):
    return KEY_NORM_RE.sub("", str(key).strip().lower())
```

Hàm chuẩn hóa tên key:

1. `str(key)`: đổi thành chuỗi.
2. `.strip()`: bỏ khoảng trắng hai đầu.
3. `.lower()`: đổi thành chữ thường.
4. `KEY_NORM_RE.sub("", ...)`: xóa ký tự không phải chữ/số.

Ví dụ `" Received-At "` thành `"receivedat"`.

`.sub(replacement, text)` là phương thức thay phần khớp regex bằng nội dung khác. Ở đây replacement là chuỗi rỗng, nghĩa là xóa.

## 3.2. `clean_line(line)`

```python
def clean_line(line):
    return line.lstrip("\ufeff").strip().replace("\u201c", '"').replace("\u201d", '"')
```

Làm sạch dòng:

- `lstrip("\ufeff")`: bỏ BOM ở đầu.
- `strip()`: bỏ khoảng trắng/xuống dòng hai đầu.
- `replace(...)`: đổi dấu ngoặc kép cong thành dấu ngoặc kép JSON thông thường.

`replace(old, new)` thay chuỗi `old` bằng `new`.

## 3.3. `rows_from_value(value)`

```python
def rows_from_value(value):
    if isinstance(value, dict):
        for key in ("rows", "records", "items", "messages"):
            nested = value.get(key)
            if isinstance(nested, list):
                if not all(isinstance(item, dict) for item in nested):
                    raise ValueError(...)
                return nested
        return [value]
    if isinstance(value, list):
        if not all(isinstance(item, dict) for item in value):
            raise ValueError(...)
        return value
    raise ValueError(...)
```

Mục đích: đưa dữ liệu đã parse thành một list các dictionary.

- `isinstance(value, dict)`: kiểm tra có phải dictionary không.
- Nếu là dictionary, thử tìm list trong các key `rows`, `records`, `items`, `messages`.
- `.get(key)`: lấy giá trị; nếu không có key thì trả `None`, không gây lỗi như `value[key]`.
- `all(...)`: chỉ trả True nếu tất cả phần tử đều thỏa điều kiện.
- `raise ValueError(...)`: chủ động báo lỗi nếu cấu trúc sai.
- `return [value]`: nếu chỉ có một object, bọc nó vào list một phần tử.
- Nếu đầu vào đã là list, kiểm tra tất cả phần tử là dictionary rồi trả về.

Ví dụ:

```python
value = {"report": "METAR EGLL", "received_at": "..."}
```

sẽ thành:

```python
[{"report": "METAR EGLL", "received_at": "..."}]
```

## 3.4. `recover_complete_objects(text)`

```python
def recover_complete_objects(text):
    """Recover complete top-level objects without closing or guessing a tail."""
```

Hàm này thử cứu các JSON object hoàn chỉnh từ một đoạn text bị hỏng. Nó không tự thêm dấu ngoặc để đoán phần cuối bị thiếu.

Các biến:

```python
decoder = json.JSONDecoder()
rows = []
object_depth = 0
array_depth = 0
in_string = False
escaped = False
index = 0
```

- `decoder`: bộ đọc JSON.
- `rows`: các object cứu được.
- `object_depth`: độ sâu của dấu `{}`.
- `array_depth`: độ sâu của dấu `[]`.
- `in_string`: đang ở bên trong chuỗi JSON hay không.
- `escaped`: ký tự trước đó là dấu escape `\` hay không.
- `index`: vị trí ký tự đang đọc.

Vòng lặp:

```python
while index < len(text):
    char = text[index]
```

`while` tiếp tục khi điều kiện đúng. `text[index]` lấy ký tự ở vị trí index. Khác `for`, `while` cho phép code tự điều khiển index.

Khi gặp `{` ở vị trí phù hợp, code thử:

```python
value, end = decoder.raw_decode(text, index)
```

`raw_decode()` đọc một JSON value bắt đầu tại vị trí index và trả về hai giá trị: object đọc được và vị trí kết thúc. Gán hai giá trị vào hai biến là kỹ thuật unpacking.

```python
try:
    ...
except json.JSONDecodeError:
    pass
else:
    ...
```

- `try`: thử chạy.
- `except`: xử lý nếu lỗi.
- `pass`: không làm gì.
- `else`: chạy nếu `try` không lỗi.

Nếu `value` là dictionary:

```python
rows.append(value)
index = end
continue
```

- `.append()` thêm phần tử vào list.
- Cập nhật vị trí sang cuối object vừa đọc.
- `continue` bỏ qua phần còn lại của lượt lặp hiện tại và chuyển sang lượt tiếp theo.

Phần theo dõi dấu ngoặc:

```python
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
```

Mục đích là phân biệt dấu ngoặc cấu trúc JSON với dấu ngoặc nằm trong nội dung chuỗi. Ví dụ `\"` bên trong chuỗi không kết thúc chuỗi.

- `+= 1`: tăng 1.
- `max(0, x)`: lấy giá trị lớn hơn giữa 0 và x, tránh độ sâu âm.

Cuối vòng lặp `index += 1` để đọc ký tự tiếp theo. Kết quả là `rows`.

## 3.5. `salvage_complete_fields(text)`

```python
def salvage_complete_fields(text):
    fields = {}
    for match in FIELD_RE.finditer(text):
        key, encoded_value = match.groups()
        try:
            value = json.loads(encoded_value)
        except json.JSONDecodeError:
            continue
        fields.setdefault(key, value)
    return fields
```

Nếu không cứu được cả object, hàm thử cứu từng cặp key/value JSON hoàn chỉnh.

- `finditer()`: tìm tất cả đoạn khớp regex.
- `match.groups()`: lấy các nhóm regex được đặt trong ngoặc.
- `json.loads()`: chuyển JSON text thành kiểu Python.
- `continue`: bỏ qua field không đọc được.
- `setdefault(key, value)`: chỉ đặt giá trị nếu key chưa tồn tại. Nếu key xuất hiện nhiều lần, giá trị đầu tiên được giữ.

Ví dụ cặp `"report": "METAR EGLL"` có thể được cứu ngay cả khi phần cuối object bị cắt.

## 3.6. `parse_raw(raw)`

Đây là hàm điều phối việc đọc raw input.

### A. Xử lý kiểu dữ liệu

```python
if isinstance(raw, bytes):
    raw = raw.decode("utf-8")
```

Bytes được decode thành chuỗi UTF-8.

Nếu raw đã là `dict` hoặc `list`, trả thẳng về. Nếu là kiểu khác không được hỗ trợ, `raise TypeError`.

### B. Làm sạch và kiểm tra rỗng

```python
text = clean_line(raw)
if not text:
    return None
```

`if not text` có nghĩa là chuỗi rỗng hoặc không có nội dung.

### C. Parse tối đa 5 lớp JSON

```python
for _ in range(5):
    try:
        value = json.loads(text)
    except json.JSONDecodeError as error:
        parse_error = error
        break
    if not isinstance(value, str):
        return value
    text = value.strip()
```

`for _ in range(5)` lặp tối đa 5 lần. `_` là tên biến quy ước khi không cần dùng số vòng lặp.

Tại sao parse nhiều lần? Dữ liệu có thể là JSON được bọc bên trong một chuỗi JSON. Sau lần parse đầu, kết quả vẫn có thể là chuỗi chứa JSON; cần parse tiếp.

- `break`: dừng vòng lặp.
- `json.loads(text)`: parse JSON.
- Nếu kết quả không còn là chuỗi, trả kết quả ngay.

### D. Ba mức cứu dữ liệu

```python
recovered = recover_complete_objects(text)
if recovered:
    return recovered

fields = salvage_complete_fields(text)
if fields:
    return fields
```

Thứ tự thử:

1. Parse JSON bình thường.
2. Cứu object hoàn chỉnh.
3. Cứu từng field hoàn chỉnh.

Nếu không thể cứu, báo `ValueError`. `raise ... from parse_error` giữ lại lỗi gốc làm nguyên nhân.

---

# 4. Nhóm chuẩn hóa cấu trúc record

## 4.1. `flatten(value, parent="", separator=".")`

```python
def flatten(value, parent="", separator="."):
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
```

Mục tiêu: làm phẳng dictionary lồng nhau.

Input:

```python
{
    "collector": {
        "message": {
            "report": "METAR EGLL"
        }
    },
    "timestamp": "..."
}
```

Output:

```python
{
    "collector.message.report": "METAR EGLL",
    "timestamp": "..."
}
```

Giải thích:

- `.items()` duyệt từng cặp key/value.
- `path` tạo đường dẫn key, ví dụ `collector.message`.
- `f"..."` là f-string, chèn biến vào chuỗi.
- `if parent else ...` là ternary expression: nếu parent có giá trị thì ghép đường dẫn; nếu không thì dùng key.
- Nếu item tiếp tục là dictionary, hàm gọi lại chính nó: đây là **recursion (đệ quy)**.
- `result.update(...)` ghép dictionary con vào dictionary hiện tại.
- Nếu item không phải dict, lưu nguyên giá trị. List được giữ nguyên, không flatten.

## 4.2. `canonical_key(key)`

```python
def canonical_key(key):
    normalized = norm_key(str(key).split(".")[-1])
    return ALIASES.get(normalized, normalized)
```

- `.split(".")`: tách đường dẫn theo dấu chấm.
- `[-1]`: lấy phần tử cuối.
- `norm_key()`: chuẩn hóa chữ.
- `ALIASES.get(normalized, normalized)`: nếu có alias thì lấy tên chuẩn, nếu không giữ tên đã chuẩn hóa.

Ví dụ `collector.message.report` lấy phần cuối là `report`.

## 4.3. `to_canonical(value)`

Hàm chuyển record về hai key chuẩn: `report`, `received_at`.

```python
candidates = {}
for key, item in flatten(value).items():
    name = canonical_key(key)
    if name not in CANON or item in (None, ""):
        continue
```

- Làm phẳng record.
- Duyệt từng key/value.
- Chuyển tên key về dạng chuẩn.
- Bỏ key không cần và giá trị rỗng.

Tiếp theo:

```python
path = str(key)
candidates.setdefault(name, []).append(
    (norm_key(path.split(".")[-1]), norm_key(path), repr(item), item)
)
```

Lưu các ứng viên. Mỗi ứng viên là tuple gồm:

1. Key cuối đã chuẩn hóa.
2. Toàn bộ đường dẫn đã chuẩn hóa.
3. Biểu diễn chuỗi của giá trị (`repr`).
4. Giá trị gốc.

Sau đó duyệt các trường chuẩn:

```python
for name in CANON:
    priority = CANONICAL_KEY_PRIORITY[name]
    options = candidates.get(name, [])
```

Duyệt thứ tự ưu tiên:

```python
for preferred_key in priority:
    matches = sorted(
        (option for option in options if option[0] == preferred_key),
        key=lambda option: option[:3],
    )
```

Cú pháp mới:

- Generator expression: `(option for option in options if ...)`, tạo các phần tử thỏa điều kiện.
- `sorted()`: sắp xếp.
- `lambda`: hàm ngắn không tên.
- `option[:3]`: lấy ba phần tử đầu của tuple.

Nếu có ứng viên:

```python
if matches:
    found[name] = matches[0][3]
    break
```

Lấy giá trị gốc ở vị trí thứ tư của tuple rồi dừng kiểm tra ưu tiên.

Cuối cùng:

```python
return {key: found.get(key) for key in CANON}
```

Đây là dictionary comprehension. Có thể viết dài thành:

```python
result = {}
for key in CANON:
    result[key] = found.get(key)
return result
```

Kết quả luôn có hai key chuẩn; nếu thiếu thì giá trị là `None`.

---

# 5. Nhóm làm sạch report và timestamp

## 5.1. `clean_report(value)`

```python
def clean_report(value):
    if value is None:
        return None
    report = re.sub(r"\s+", " ", str(value)).strip().upper()
    return report[:-1].rstrip() if report.endswith("=") else report
```

Các bước:

1. Nếu `None`, trả `None`.
2. Đổi thành chuỗi.
3. `re.sub(r"\s+", " ", ...)`: gom nhiều khoảng trắng/xuống dòng thành một dấu cách.
4. `strip()`: bỏ khoảng trắng hai đầu.
5. `upper()`: chuyển chữ hoa.
6. Nếu cuối chuỗi có `=`, bỏ nó.

`report[:-1]` là slicing: lấy chuỗi từ đầu đến trước ký tự cuối. `endswith("=")` kiểm tra chuỗi có kết thúc bằng dấu `=` không.

## 5.2. `clean_timestamp(value)`

Mục tiêu: chuyển timestamp về dạng UTC:

```text
YYYY-MM-DDTHH:MM:SSZ
```

### Bước 1: kiểm tra giá trị

Nếu `None` hoặc chuỗi rỗng thì trả `None`.

### Bước 2: Unix timestamp

```python
if EPOCH_RE.fullmatch(text) and len(text) in (10, 13, 16):
    scale = {10: 1, 13: 1000, 16: 1000000}[len(text)]
```

Code nhận:
- 10 chữ số: giây.
- 13 chữ số: mili giây.
- 16 chữ số: micro giây.

Chia số cho hệ số tương ứng rồi:

```python
datetime.fromtimestamp(int(text) / scale, tz=timezone.utc)
```

Chuyển Unix timestamp thành datetime UTC.

`strftime("%Y-%m-%dT%H:%M:%SZ")` định dạng datetime thành chuỗi. `%Y` năm, `%m` tháng, `%d` ngày, `%H` giờ, `%M` phút, `%S` giây.

### Bước 3: timezone dạng `+07`

```python
hour_offset = HOUR_OFFSET_RE.fullmatch(text)
if hour_offset:
    text = f"{hour_offset.group(1)}{hour_offset.group(2)}:00"
```

Đổi `+07` thành `+07:00` để Python đọc được ISO timestamp.

`group(1)`, `group(2)` lấy các phần regex nằm trong ngoặc.

### Bước 4: parse ISO

```python
timestamp = datetime.fromisoformat(text.replace("Z", "+00:00"))
```

`fromisoformat()` chuyển chuỗi ISO thành datetime.

### Bước 5: đưa về UTC

```python
if timestamp.tzinfo is None:
    timestamp = timestamp.replace(tzinfo=timezone.utc)
else:
    timestamp = timestamp.astimezone(timezone.utc)
```

- Không có timezone: code giả định giá trị đã là UTC và gắn UTC.
- Có timezone: chuyển thời điểm sang UTC.

`replace(tzinfo=...)` chỉ gắn thông tin timezone; `astimezone(...)` thực sự chuyển thời điểm sang múi giờ khác. Hai thao tác khác nhau.

## 5.3. `normalize_row(value)`

```python
def normalize_row(value):
    if not isinstance(value, dict):
        return None
    try:
        row = to_canonical(value)
        report = clean_report(row["report"])
        received_at = clean_timestamp(row["received_at"])
        if report is None or received_at is None:
            return None
        return {"report": report, "received_at": received_at}
    except (TypeError, ValueError, OverflowError, AttributeError):
        return None
```

Chuẩn hóa một record:

1. Xác nhận đầu vào là dictionary.
2. `to_canonical`: chuẩn hóa key.
3. `clean_report`: làm sạch METAR.
4. `clean_timestamp`: chuẩn hóa thời gian nhận.
5. Nếu thiếu report hoặc received_at thì loại record.
6. Nếu gặp các lỗi dữ liệu đã liệt kê thì trả `None`.

`try/except` giúp một record lỗi không nhất thiết làm dừng toàn bộ chương trình.

## 5.4. `normalize_rows(raw)`

```python
def normalize_rows(raw):
    try:
        value = parse_raw(raw)
        if value is None:
            return []
        rows = rows_from_value(value)
    except (...):
        return []

    normalized = []
    for row in rows:
        try:
            item = normalize_row(row)
        except (...):
            continue
        if item is not None:
            normalized.append(item)
    return normalized
```

Đây là hàm chuẩn hóa nhiều record.

- Đọc raw bằng `parse_raw`.
- Nếu không có dữ liệu, trả list rỗng `[]`.
- Đưa dữ liệu về list bằng `rows_from_value`.
- Duyệt từng row, gọi `normalize_row`.
- Chỉ append record hợp lệ.
- Nếu một row lỗi, `continue` sang row kế tiếp.

**Luồng:** raw → parse JSON → tách rows → chuẩn hóa từng row → danh sách record chuẩn.

---

# 6. Nhóm trích xuất thông tin METAR

## 6.1. `extract_station(report)`

Mục tiêu: lấy mã sân bay ICAO như `EGLL`, `VVTS`.

```python
tokens = re.findall(r"[A-Z0-9/]+", str(report).upper())
```

`findall()` tìm tất cả đoạn khớp regex và trả về list. Ví dụ METAR được tách thành các token như `METAR`, `EGLL`, `312050Z`, `24012KT`.

```python
for index, token in enumerate(tokens):
```

`enumerate()` cho cả vị trí và giá trị. Ví dụ index 0 là `METAR`, index 1 là `EGLL`.

Code tìm token `METAR` hoặc `SPECI`, sau đó xem token kế tiếp. Nếu là `COR`, bỏ qua nó. Nếu token tiếp theo là 4 chữ cái hợp lệ và không phải `AUTO`, trả về station.

Nếu cách chuẩn không tìm được, code dùng vòng lặp thứ hai để tìm token 4 chữ cái trước nhóm observation time. Đây là logic dự phòng.

## 6.2. `extract_received_at(row)`

```python
def extract_received_at(row):
    if not isinstance(row, dict):
        return None
    return clean_timestamp(row.get("received_at"))
```

Kiểm tra row là dictionary, lấy `received_at`, rồi chuẩn hóa timestamp.

## 6.3. `extract_wind_kt(report)`

Mục tiêu: trích tốc độ gió và đổi về knots.

```python
match = WIND_RE.search(str(report).strip().upper())
```

Tìm nhóm gió. Regex cho phép hướng 3 chữ số hoặc `VRB`, tốc độ 2–3 chữ số, gust tùy chọn và đơn vị `KT`, `MPS`, `KMH`.

```python
speed = int(match.group(1))
unit = match.group(2)
```

Lấy tốc độ và đơn vị.

Chuyển đổi:

```python
if unit == "KT":
    knots = speed
elif unit == "MPS":
    knots = speed * 1.94384
elif unit == "KMH":
    knots = speed / 1.852
```

- KT: giữ nguyên.
- MPS: nhân 1.94384.
- KMH: chia 1.852.

```python
return int(knots + 0.5)
```

Làm tròn số không âm về số nguyên gần nhất. Nếu không tìm được nhóm gió hoặc chuyển đổi lỗi thì trả `None`.

## 6.4. `sm_to_meters(value)`

```python
meters = value * Decimal("1609.344")
```

1 statute mile = 1609.344 mét.

```python
meters.quantize(Decimal("1"), rounding=ROUND_HALF_UP)
```

Làm tròn đến mét nguyên.

```python
min(9999, ...)
```

Giới hạn kết quả tối đa 9999.

`Decimal` được dùng để giảm vấn đề sai số số thập phân trong tính toán.

## 6.5. `extract_visibility_m(report)`

Mục tiêu: trích tầm nhìn và trả về mét.

1. Kiểm tra report có phải chuỗi/bytes.
2. Gom khoảng trắng, chuyển chữ hoa và tách token.
3. Nếu có `CAVOK`, trả `9999`.
4. Nếu có `////`, trả `None`.
5. Tìm nhóm tầm nhìn bằng mét sau observation time.
6. Dừng tìm khi gặp `RMK`, `NOSIG`, `TEMPO`, `BECMG`.
7. Nếu không có mét, thử statute miles.

Phần tìm mét:

```python
after_observation = False
for token in tokens:
    if OBSERVATION_TIME_RE.fullmatch(token):
        after_observation = True
        continue
    if not after_observation:
        continue
```

Chỉ tìm sau nhóm giờ quan sát để tránh nhầm số trong header.

```python
if token in {"RMK", "NOSIG", "TEMPO", "BECMG"}:
    break
```

Dừng tại marker phần remarks/outlook.

```python
if re.fullmatch(r"\d{4,5}", token) and not token.startswith("R"):
```

Tìm token có 4 hoặc 5 chữ số, tránh nhóm bắt đầu bằng R như runway visual range.

Nếu tìm thấy, chuyển thành số nguyên và giới hạn tối đa 9999.

### Ba dạng statute miles

**A. Dạng hỗn hợp `1 1/2SM`**

`MIXED_SM_RE` lấy phần nguyên, tử số, mẫu số. Tính `1 + 1/2 = 1.5 SM`, sau đó gọi `sm_to_meters()`.

**B. Dạng phân số `1/2SM`**

`FRACTION_SM_RE` lấy tử số/mẫu số, tính phân số rồi đổi sang mét.

**C. Dạng nguyên `10SM`**

`INTEGER_SM_RE` lấy số nguyên, chuyển sang Decimal rồi đổi sang mét.

Nếu mẫu số bằng hoặc nhỏ hơn 0, hoặc có lỗi Decimal, trả `None`.

## 6.6. `extract_ceiling_ft(report)`

Mục tiêu: tìm trần mây thấp nhất trong nhóm `BKN`, `OVC`, `VV`.

```python
match = re.fullmatch(r"(BKN|OVC|VV)(\d{3})(?:[A-Z]+)?", token)
```

Các phần:

- `(BKN|OVC|VV)`: một trong ba loại.
- `(\d{3})`: ba chữ số độ cao theo đơn vị 100 feet.
- `(?:[A-Z]+)?`: hậu tố chữ cái tùy chọn như `CB`, `TCU`.

Ví dụ:

- `BKN015` → 1500 feet.
- `OVC008` → 800 feet.
- `BKN015CB` → 1500 feet.
- `VV002` → 200 feet.

Code đưa từng độ cao hợp lệ vào `candidates`.

```python
return min(candidates) if candidates else None
```

Nếu có ứng viên, lấy độ cao thấp nhất. Nếu không có thì `None`. Đây là ternary expression: `A if điều_kiện else B`.

## 6.7. `extract_temp_c(report)`

Mục tiêu: lấy nhiệt độ Celsius và trả về chuỗi có đúng một chữ số thập phân.

Đầu tiên tìm `RMK`:

```python
rmk_match = re.search(r"\bRMK\b", text)
```

Nếu có, tìm nhóm nhiệt độ chính xác trong phần remarks:

```python
precision_match = re.search(r"\bT([01])(\d{3})([01])(\d{3})\b", rmk_text)
```

Nhóm `T` mã hóa dấu và nhiệt độ theo phần mười, sau đó là dấu và điểm sương. Code lấy phần nhiệt độ đầu tiên.

```python
tenths = int(precision_match.group(2))
```

Ví dụ 050 là 5.0°C.

```python
temperature = -tenths if precision_match.group(1) == "1" and tenths != 0 else tenths
```

Nếu dấu là 1 và số khác 0 thì chuyển âm.

```python
magnitude // 10
magnitude % 10
```

- `//`: chia lấy phần nguyên.
- `%`: lấy phần dư.

Ví dụ 57 → phần nguyên 5, phần thập phân 7 → `"5.7"`.

Nếu không có nhóm chính xác trong RMK, code tìm nhóm nhiệt độ chuẩn:

```python
standard_match = re.search(r"\b(M?\d{2})/(M?\d{2})\b", body)
```

Ví dụ `12/08`, `M05/M10`.

Nếu nhiệt độ bắt đầu bằng M thì là số âm. Cuối cùng:

```python
return f"{temperature:.1f}"
```

F-string định dạng một chữ số thập phân. Ví dụ `12` thành `"12.0"`. Kết quả là **string**, không phải float.

## 6.8. `extract_altimeter_hpa(report)`

Mục tiêu: lấy áp suất từ nhóm A hoặc Q và trả về hPa với một chữ số thập phân.

Trước tiên code bỏ phần sau `RMK` để chỉ đọc báo cáo chính.

### Dạng A: inHg

```python
a_match = re.search(r"\bA(\d{4})\b", body)
```
