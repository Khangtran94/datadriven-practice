# Giải thích `handler.py` – Tuần 10 "The Ceiling"

> Tài liệu dành cho người mới học Python (đã biết `def`, `for`, `if`).
> Mỗi phần mới mình giải thích từ đầu, kèm ví dụ chạy thật.

---

## 1. Bài toán là gì?

Sân bay báo cáo thời tiết bằng **METAR** – một dòng mã ngắn, ví dụ:

```
METAR EGLL 312350Z 34005KT 9999 BKN015 M02/M04 Q1013=
```

Đọc từng nhóm:

| Nhóm | Ý nghĩa |
|---|---|
| `METAR` | loại báo cáo |
| `EGLL` | mã sân bay (London Heathrow) → cột **station** |
| `312350Z` | ngày 31, 23:50 giờ UTC → cột **observed_at** |
| `34005KT` | gió hướng 340°, tốc độ 5 knot → cột **wind_kt** |
| `9999` | tầm nhìn 9999 mét (≥ 10 km) → cột **visibility_m** |
| `BKN015` | mây nhiều (broken) ở độ cao 1500 ft → cột **ceiling_ft** |
| `M02/M04` | nhiệt độ −2°C, điểm sương −4°C → cột **temp_c** |
| `Q1013` | áp suất 1013 hPa → cột **altimeter_hpa** |

Dữ liệu đầu vào là các **dòng log JSON** rất bẩn, ví dụ:

```json
{"feed":"relay","ts":"1767225600","msg":"METAR EGLL 312350Z 34005KT 9999 BKN015 M02/M04 Q1013="}
```

**Nhiệm vụ của `handler.py`:** với mỗi dòng log, trả về một dòng sạch:

```python
{'station': 'EGLL', 'observed_at': '2025-12-31T23:50:00Z', 'wind_kt': 5,
 'visibility_m': 9999, 'ceiling_ft': 1500, 'temp_c': '-2.0', 'altimeter_hpa': '1013.0'}
```

(Mình đã chạy thử đúng dòng trên, kết quả đúng như vậy.)

---

## 2. Bức tranh tổng thể (đọc phần này trước)

Hệ thống chấm điểm sẽ làm như sau:

```
h = Handler()
for mỗi dòng log:
    h.process(dòng_log)      # trả về list các dòng sạch
h.finalize()                 # gọi 1 lần ở cuối
```

Bên trong `process`, dữ liệu đi qua **2 giai đoạn**:

```
dòng log thô (text)
   │
   ▼  GIAI ĐOẠN 1: normalize_rows()  → "lấy ra câu METAR + thời điểm nhận"
   │     parse_raw()        đọc JSON (kể cả JSON hỏng)
   │     rows_from_value()  tìm danh sách bản ghi
   │     to_canonical()     đổi tên key lung tung về 2 key chuẩn
   │     clean_report()     làm sạch câu METAR
   │     clean_timestamp()  đổi thời gian về dạng chuẩn
   │   → [{"report": "...", "received_at": "..."}]
   │
   ▼  GIAI ĐOẠN 2: extract_columns() → "đọc câu METAR, lấy 7 cột"
   │     extract_station / observed_at / wind / visibility / ceiling / temp / altimeter
   │   → [{station, observed_at, wind_kt, ...}]
   │
   ▼  Handler.process(): bỏ dòng trùng, trả kết quả
```

Chỉ cần nhớ: **Giai đoạn 1 = làm sạch JSON. Giai đoạn 2 = đọc mã METAR.**

---

## 3. Kiến thức Python dùng trong file này

Nếu bạn đã biết `def/for/if` thì chỉ cần xem lướt phần mới.

### 3.1 `try / except` – bắt lỗi
```python
try:
    x = int("abc")        # lỗi!
except ValueError:
    x = None              # lỗi thì chạy vào đây thay vì làm chương trình sập
```
File này dùng **rất nhiều** `try/except`, vì dữ liệu bẩn nên lỗi xảy ra thường xuyên. Mục đích: *một dòng hỏng không được làm sập cả chương trình*.

### 3.2 `raise` – tự ném lỗi
```python
raise ValueError("Dữ liệu sai")
```
Ngược lại với `except`: chủ động báo lỗi để chỗ khác bắt.

### 3.3 Dictionary (dict) và các hàm hay dùng
```python
d = {"a": 1}
d.get("b")              # None nếu không có (không báo lỗi)
d.setdefault("b", 5)    # nếu chưa có "b" thì gán 5; có rồi thì giữ nguyên
d.items()               # lấy từng cặp (key, value)
```

### 3.4 Tuple – list "không đổi được"
```python
t = (1, 2, 3)
```
File dùng tuple để gói 5 giá trị đo (`_pack_record`) và để so sánh nhanh.

### 3.5 f-string
```python
name = "An"
f"Xin chào {name}"      # → "Xin chào An"
f"{3.14159:.1f}"        # → "3.1"  (làm tròn 1 chữ số thập phân)
```

### 3.6 Slicing (cắt chuỗi)
```python
s = "ABC="
s[:-1]    # "ABC"  (bỏ ký tự cuối)
s[1:]     # "BC="  (bỏ ký tự đầu)
```

### 3.7 Regex (biểu thức chính quy) – quan trọng nhất file này
Regex là "mẫu" để tìm chữ trong chuỗi. Bảng ký hiệu cần biết:

| Ký hiệu | Nghĩa | Ví dụ |
|---|---|---|
| `\d` | 1 chữ số | `\d\d` khớp `05` |
| `{3}` | đúng 3 lần | `\d{3}` khớp `340` |
| `{2,3}` | 2 đến 3 lần | |
| `+` | 1 lần trở lên | `\d+` khớp `12345` |
| `?` | có hoặc không | `M?` khớp `M` hoặc rỗng |
| `[A-Z]` | 1 chữ in hoa | `[A-Z]{4}` khớp `EGLL` |
| `[^a-z0-9]` | ký tự **không** phải chữ thường/số | |
| `\s` | khoảng trắng | |
| `^` / `$` | đầu / cuối chuỗi | |
| `\b` | ranh giới từ | `\bA(\d{4})\b` |
| `( )` | **nhóm** – lấy phần trong ngoặc ra dùng | `match.group(1)` |
| `(?: )` | nhóm nhưng **không** lấy ra | |
| `\|` | hoặc | `(KT\|MPS\|KMH)` |

Các hàm regex dùng trong file:

```python
re.compile(mẫu)                 # biên dịch mẫu 1 lần, dùng lại nhiều lần
mẫu.search(text)                # tìm mẫu ở BẤT KỲ đâu trong text
mẫu.fullmatch(text)             # CẢ chuỗi phải khớp mẫu
mẫu.sub("", text)               # thay phần khớp bằng ""
re.findall(mẫu, text)           # lấy tất cả phần khớp
match.group(1)                  # lấy nội dung nhóm số 1
```

### 3.8 `Decimal` – số thập phân chính xác
`float` hay sai số (`0.1+0.2 = 0.30000000000000004`). `Decimal` thì chính xác, dùng khi làm tròn tiền/đơn vị đo.
`ROUND_HALF_UP` = làm tròn kiểu thường (0.5 → lên).

### 3.9 `lambda`, `min(..., key=...)`, `sorted(..., key=...)`
```python
min(candidates, key=lambda c: abs(c - 10))   # chọn phần tử có abs(c-10) nhỏ nhất
```
`lambda x: ...` là hàm vô danh viết 1 dòng.

### 3.10 `class` và `self`
```python
class Handler:
    def __init__(self):        # chạy 1 lần khi tạo: h = Handler()
        self.records_map = {}  # "bộ nhớ" của đối tượng, sống suốt chương trình
    def process(self, raw):    # self = chính đối tượng đó
        ...
```

---

## 4. Phần đầu file: import và hằng số

```python
import json
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
```
Gọi các thư viện: `json` (đọc JSON), `re` (regex), `datetime` (ngày giờ), `decimal` (số chính xác).
(`timedelta` được import nhưng không dùng.)

### 4.1 `CANON` – 2 key chuẩn
```python
CANON = ("report", "received_at")
```
Dù log đặt tên lung tung, cuối cùng ta chỉ cần 2 thứ:
- `report` – câu METAR
- `received_at` – thời điểm collector nhận dòng này

### 4.2 `ALIASES` – bảng đổi tên
```python
ALIASES = {"metar": "report", "raw": "report", "text": "report", "msg": "report",
           "ts": "received_at", "timestamp": "received_at", ...}
```
Nghĩa là key `msg`, `raw`, `text`... đều là "report"; key `ts`, `timestamp`... đều là "received_at".
`"source": "feed"` và `"feedid": "feed"` đổi sang `feed`, nhưng `feed` **không nằm trong `CANON`** nên sẽ bị bỏ qua (đây chính là "bookkeeping fields" – trường ghi chú của collector, không cần).

### 4.3 `CANONICAL_KEY_PRIORITY` – thứ tự ưu tiên
Nếu 1 dòng có **cả** `report` lẫn `msg`, lấy cái nào? Bảng này nói: ưu tiên `report` trước, rồi `metar`, `raw`, `rawtext`, `text`, `message`, `msg`.

### 4.4 Các regex đã biên dịch sẵn

| Tên | Dùng để | Giải thích |
|---|---|---|
| `KEY_NORM_RE` `[^a-z0-9]+` | chuẩn hoá tên key | xoá mọi ký tự không phải chữ/số |
| `HOUR_OFFSET_RE` | nhận `2026-01-01 08:00:00+07` | ngày giờ + múi giờ chỉ có giờ |
| `EPOCH_RE` `^\d+$` | nhận chuỗi toàn số | timestamp epoch |
| `WIND_RE` | bắt nhóm gió | xem 8.3 |
| `ICAO_RE` `^[A-Z]{4}$` | mã sân bay | đúng 4 chữ in hoa |
| `REPORT_TYPE_RE` | từ `METAR` hoặc `SPECI` | |
| `OBSERVATION_TIME_RE` `^\d{6}Z$` | nhóm giờ quan trắc | vd `312350Z` |
| `MIXED_SM_RE` | tầm nhìn dặm hỗn số | `1 1/2SM` |
| `FRACTION_SM_RE` | tầm nhìn phân số | `1/2SM` |
| `INTEGER_SM_RE` | tầm nhìn số nguyên | `10SM` |
| `FIELD_RE` | tìm cặp `"key": value` trong JSON hỏng | xem 5.4 |

> Cách đọc `MIXED_SM_RE = \b(M?)(\d+)\s+(\d+)/(\d+)SM\b`:
> `M?` (có thể có chữ M = "nhỏ hơn") → số nguyên → khoảng trắng → tử số `/` mẫu số → `SM`.
> Với `1 1/2SM`: nhóm 2 = `1`, nhóm 3 = `1`, nhóm 4 = `2`.

---

## 5. GIAI ĐOẠN 1 – Làm sạch JSON

### 5.1 `norm_key(key)` – chuẩn hoá tên key
```python
def norm_key(key):
    return KEY_NORM_RE.sub("", str(key).strip().lower())
```
Chữ thường + xoá ký tự lạ. Vậy `"Raw_Text"`, `"raw-text"`, `"RAWTEXT"` đều thành `"rawtext"`. Nhờ vậy 1 mục trong `ALIASES` bắt được rất nhiều cách viết.

### 5.2 `clean_line(line)` – dọn dòng thô
```python
return line.lstrip("\ufeff").strip().replace("\u201c", '"').replace("\u201d", '"')
```
- `\ufeff` = ký tự BOM vô hình do Windows chèn đầu file → bỏ.
- `.strip()` bỏ khoảng trắng 2 đầu.
- `\u201c` `\u201d` = dấu ngoặc kép cong `“ ”` → đổi thành `"` thẳng để JSON đọc được.

### 5.3 `rows_from_value(value)` – tìm danh sách bản ghi
Sau khi đọc JSON, kết quả có thể là:
- 1 dict → bình thường → trả `[value]`
- dict có chứa danh sách ở key `rows`/`records`/`items`/`messages` → trả danh sách đó
- 1 list các dict → trả luôn
- thứ khác → `raise ValueError`

Hàm `all(isinstance(item, dict) for item in nested)` = "mọi phần tử đều là dict?".

### 5.4 Hai "chiêu cứu" khi JSON hỏng

#### `recover_complete_objects(text)` – nhặt các object `{...}` còn nguyên
Khi `json.loads` thất bại (dòng bị cắt, hoặc dính 2 object), hàm này **đi từng ký tự**:
- Theo dõi: đang trong chuỗi `"..."` không (`in_string`), có đang bị escape `\` không (`escaped`), độ sâu `{}` và `[]`.
- Gặp `{` ở ngoài chuỗi, độ sâu 0 → thử `decoder.raw_decode(text, index)`.
  - `raw_decode` đọc 1 giá trị JSON bắt đầu từ vị trí `index` và trả `(giá_trị, vị_trí_kết_thúc)`.
  - Thành công và là dict → thêm vào `rows`, nhảy `index` tới `end`, `continue`.
- Không thành công thì đi tiếp.

Điểm hay: hàm **không tự đóng ngoặc hay đoán phần đuôi** – chỉ lấy object nào hoàn chỉnh thật.

#### `salvage_complete_fields(text)` – nhặt từng cặp key/value còn nguyên
Nếu cả object cũng hỏng, dùng `FIELD_RE` tìm các cặp dạng `"key": "value"` (hoặc số, true/false/null) còn nguyên vẹn, rồi `json.loads` từng giá trị. `fields.setdefault(key, value)` giữ cặp **đầu tiên** nếu key lặp.

### 5.5 `parse_raw(raw)` – hàm đọc JSON chính
Thứ tự xử lý:

1. Nếu `raw` là `bytes` → giải mã UTF-8.
2. Nếu đã là dict/list → trả luôn. Kiểu khác → `raise TypeError`.
3. `clean_line` → nếu rỗng trả `None`.
4. **Vòng lặp tối đa 5 lần** `json.loads`:
   ```python
   for _ in range(5):
       try:
           value = json.loads(text)
       except json.JSONDecodeError as error:
           parse_error = error
           break
       if not isinstance(value, str):
           return value        # được dict/list → xong
       text = value.strip()    # được 1 chuỗi → JSON bị "bọc" trong chuỗi, bóc tiếp
   ```
   Tại sao lặp? Có dòng JSON bị **mã hoá 2 lần**: `"{\"msg\": \"...\"}"`. Lần 1 ra chuỗi, lần 2 ra dict.
5. Nếu vẫn lỗi → thử `recover_complete_objects`, rồi `salvage_complete_fields`.
6. Hết cách → `raise ValueError(...)`.

(`_` là tên biến "không quan tâm giá trị", chỉ cần lặp 5 lần.)

### 5.6 `flatten(value, parent="", separator=".")` – làm phẳng dict lồng nhau
```python
{"a": {"b": 1, "c": {"d": 2}}}   →   {"a.b": 1, "a.c.d": 2}
```
Hàm **gọi lại chính nó** (đệ quy): gặp dict con thì flatten tiếp với đường dẫn dài hơn. List được giữ nguyên là giá trị. Lợi ích: dù `msg` nằm ở tầng nào (log của relay để report "1 tầng dưới `msg`") cũng tìm thấy.

### 5.7 `canonical_key(key)`
```python
normalized = norm_key(str(key).split(".")[-1])   # lấy phần cuối đường dẫn: "a.b.Msg" → "Msg" → "msg"
return ALIASES.get(normalized, normalized)       # có trong bảng thì đổi tên, không thì giữ
```

### 5.8 `to_canonical(value)` – gom về đúng 2 key
Chia 2 bước:

**Bước A – thu thập ứng viên:** duyệt mọi cặp đã flatten; nếu tên chuẩn nằm trong `CANON` và giá trị không phải `None`/`""` thì ghi vào `candidates[tên]` một tuple gồm (tên cuối chuẩn hoá, đường dẫn chuẩn hoá, repr, giá trị).

**Bước B – chọn người thắng:** với mỗi tên trong `CANON`, đi theo thứ tự `CANONICAL_KEY_PRIORITY`; ứng viên nào có tên cuối trùng key ưu tiên đầu tiên thì thắng (sắp xếp để kết quả luôn ổn định, không phụ thuộc thứ tự key).

Kết quả luôn là dict có đủ 2 key: `{"report": ..., "received_at": ...}` (thiếu thì là `None`).

### 5.9 `clean_report(value)` – làm sạch câu METAR
```python
report = re.sub(r"\s+", " ", str(value)).strip().upper()
return report[:-1].rstrip() if report.endswith("=") else report
```
- Mọi khoảng trắng/xuống dòng liên tiếp → 1 dấu cách (sửa lỗi "line break in the middle").
- Viết hoa hết (sửa lỗi "lower case").
- Bỏ dấu `=` cuối.

Dòng `... if ... else ...` là **toán tử 3 ngôi**: `A if điều_kiện else B`.

### 5.10 `clean_timestamp(value)` – chuẩn hoá thời gian
Kết quả luôn dạng `2026-01-01T00:00:00Z` (UTC). Xử lý theo thứ tự:

1. **Chuỗi toàn số dài 10/13/16 chữ số** = epoch giây / mili-giây / micro-giây:
   ```python
   scale = {10: 1, 13: 1000, 16: 1000000}[len(text)]
   datetime.fromtimestamp(int(text) / scale, tz=timezone.utc)
   ```
   Ví dụ `"1767225600"` → `2026-01-01T00:00:00Z`.
2. Dạng `2026-01-01 08:00:00+07` (múi giờ chỉ có giờ) → nối thêm `:00` thành `+07:00` để Python hiểu.
3. `datetime.fromisoformat(...)` (thay `Z` thành `+00:00` vì Python đọc `Z` không ổn).
4. Không có múi giờ → coi là UTC. Có múi giờ → `astimezone(timezone.utc)` đổi về UTC.

Lỗi → trả `None`.

### 5.11 `normalize_row` và `normalize_rows`
```python
def normalize_row(value):    # xử lý 1 dict
    row = to_canonical(value)
    report = clean_report(row["report"])
    received_at = clean_timestamp(row["received_at"])
    if report is None or received_at is None:
        return None          # thiếu 1 trong 2 → bỏ
    return {"report": report, "received_at": received_at}
```
```python
def normalize_rows(raw):     # xử lý 1 dòng log thô → list các row sạch
    value = parse_raw(raw)
    rows = rows_from_value(value)
    for row in rows:
        item = normalize_row(row)
        if item is not None:
            normalized.append(item)
```
Lỗi ở đâu cũng được bắt → trả `[]`, **không bao giờ sập**.

---

## 6. GIAI ĐOẠN 2 – Đọc mã METAR (7 cột)

Mỗi hàm `extract_...` nhận **câu METAR** và trả về 1 cột. Cùng một mẫu:
chuẩn hoá chuỗi → dùng regex/tách từ → đổi đơn vị → trả giá trị hoặc `None`.

### 6.1 `extract_station(report)` – mã sân bay
```python
tokens = re.findall(r"[A-Z0-9/]+", str(report).upper())   # tách thành từ
```
- **Cách 1:** tìm từ `METAR`/`SPECI`; từ ngay sau nó (bỏ qua `COR`) mà đúng 4 chữ cái và khác `AUTO` → đó là station.
- **Cách 2 (dự phòng):** duyệt từ đầu, dừng khi gặp nhóm giờ `312350Z`; từ 4 chữ cái đầu tiên (khác `AUTO`) là station.

`metar egll 300120z ...` (chữ thường) vẫn đúng vì đã `.upper()`.

### 6.2 `extract_observed_at(report, received_at)` – giờ quan trắc ⭐
METAR chỉ ghi **ngày + giờ + phút** (`312350Z`), **không có tháng, năm**. Phải suy ra tháng/năm từ `received_at`.

Cách làm:
1. Tách `DD`, `HH`, `MM` bằng regex `\b(\d{2})(\d{2})(\d{2})Z\b`. Giờ > 23 hoặc phút > 59 → `None` (vì vậy báo cáo `2400` bị bỏ – một điểm yếu).
2. Lấy `received_at` làm mốc `reference`.
3. Thử 3 ứng viên: **tháng trước, tháng này, tháng sau** của mốc:
   ```python
   month_index = reference.year * 12 + (reference.month - 1) + month_offset
   year  = month_index // 12
   month = month_index - year * 12 + 1
   ```
   Đây là mẹo đổi (năm, tháng) thành 1 số liên tục để cộng/trừ tháng mà không lo qua năm. Tháng không có ngày đó (vd ngày 31 của tháng 2) → `datetime(...)` ném `ValueError` → `continue` bỏ qua.
4. Chọn ứng viên **gần `received_at` nhất**:
   ```python
   min(candidates, key=lambda candidate: (abs((candidate - reference).total_seconds()), candidate))
   ```

**Ví dụ:** dòng nhận lúc `2026-01-01T00:00:00Z` nhưng METAR ghi ngày 31 → ứng viên: 31/12/2025 (cách ~10 phút), 31/01/2026 (cách 30 ngày) → chọn **2025-12-31T23:50:00Z**. Đây chính là xử lý lỗi "Sent late, after an outage" trong README.

### 6.3 `extract_wind_kt(report)` – gió (knot)
```python
WIND_RE = (?:^|\s)(?:[0-9]{3}|VRB)([0-9]{2,3})(?:G[0-9]{2,3})?(KT|MPS|KMH)(?:\s|=|$)
```
Đọc: *đầu chuỗi hoặc dấu cách* → *3 chữ số hướng gió hoặc `VRB`* → **(2–3 chữ số tốc độ)** → *tuỳ chọn gió giật `G20`* → **(đơn vị)** → *dấu cách / `=` / hết chuỗi*.

Ví dụ `18012G20KT`: hướng 180, tốc độ **12**, giật 20, đơn vị **KT**.

Đổi đơn vị:
```python
KT  → knots = speed
MPS → knots = speed * 1.94384     # m/s → knot
KMH → knots = speed / 1.852       # km/h → knot
return int(knots + 0.5)           # làm tròn lên kiểu thường
```
(`int(x + 0.5)` là mẹo làm tròn số dương.)

### 6.4 `extract_visibility_m(report)` – tầm nhìn (mét)
Thứ tự kiểm tra:
1. Có từ `CAVOK` → **9999**.
2. Có `////` (cảm biến hỏng) → `None`.
3. Duyệt các từ **sau nhóm giờ**, dừng khi gặp `RMK/NOSIG/TEMPO/BECMG` (phần ghi chú/dự báo – không phải quan trắc hiện tại). Từ đầu tiên gồm **4–5 chữ số** → tầm nhìn mét, tối đa 9999.
4. Nếu không có, tìm **dặm (SM)**:
   - hỗn số `1 1/2SM` → `1 + 1/2 = 1.5` dặm
   - phân số `1/2SM` → `0.5` dặm
   - số nguyên `10SM`
   rồi gọi `sm_to_meters`.

`sm_to_meters`: `dặm × 1609.344` → làm tròn thành số nguyên → `min(9999, ...)` (không vượt 9999).
Ví dụ `1 1/2SM` → 1.5 × 1609.344 = **2414 m** (đúng với kết quả mình chạy thử).

### 6.5 `extract_ceiling_ft(report)` – trần mây (feet)
Trần mây = lớp mây **BKN** (nhiều), **OVC** (kín) hoặc **VV** (tầm nhìn thẳng đứng) **thấp nhất**.
```python
match = re.fullmatch(r"(BKN|OVC|VV)(\d{3})(?:[A-Z]+)?", token)
candidates.append(int(match.group(2)) * 100)     # 015 → 1500 ft
return min(candidates) if candidates else None
```
- `(?:[A-Z]+)?` cho phép đuôi `CB` / `TCU` (vd `BKN015CB`).
- Mây `FEW`, `SCT` **không** tính là trần.
- Dừng khi gặp `RMK/NOSIG/TEMPO/BECMG`.

### 6.6 `extract_temp_c(report)` – nhiệt độ (trả về **chuỗi** 1 số lẻ)
Hai nguồn, ưu tiên nguồn chính xác hơn:

1. **Nhóm T trong phần `RMK`** (kiểu Mỹ, có phần mười): `T10501106`
   - `T` + `1` (dấu: 1 = âm, 0 = dương) + `050` (= 5.0 độ) + `1` + `106` (điểm sương).
   - `T10501106` → **−5.0** (và đúng là mình đã chạy ra `-5.0`).
2. **Nhóm thường trong thân báo cáo:** `M05/M10` hoặc `05/M01`
   - `M` = âm (minus). `M02` → −2 → `"-2.0"`.

Dòng `f"{sign}{magnitude // 10}.{magnitude % 10}"` tách số nguyên và phần mười: 50 → `5` và `0` → `"5.0"`. (`//` chia lấy phần nguyên, `%` chia lấy dư.)

### 6.7 `extract_altimeter_hpa(report)` – áp suất (hPa)
Chỉ xét phần thân (trước `RMK`).
- **Nhóm A (inHg, kiểu Mỹ):** `A3001` → `30.01` inHg. Phải nằm trong 28.0–32.0, nhân `33.8639` → hPa, làm tròn 1 số lẻ. Ví dụ `A3001` → **1016.3**.
- **Nhóm Q (hPa):** `Q1013` → phải trong 850–1100 → `"1013.0"`.

Cả hai trả về **chuỗi** có đúng 1 chữ số thập phân (`format(hpa, ".1f")`).

### 6.8 `extract_columns(rows)` (hàm cấp module)
Ghép tất cả lại:
```python
for row in rows:
    station     = extract_station(row.get("report"))
    received_at = extract_received_at(row)
    observed_at = extract_observed_at(row.get("report"), received_at)
    if station is None or received_at is None or observed_at is None:
        continue                      # thiếu 3 thứ này thì bỏ dòng
    output.append({ "station": ..., "observed_at": ..., "wind_kt": ..., ... })
```
**Quy tắc quan trọng:** `station` và `observed_at` là *khoá nhận dạng* nên bắt buộc có. 5 cột còn lại (gió, tầm nhìn...) **được phép là `None`** (cảm biến hỏng là chuyện bình thường).

---

## 7. Phần chống trùng lặp

### 7.1 Ba hàm phụ nhỏ
```python
def _record_key(row):        # tạo "khoá" nhận dạng
    return f"{station}|{observed_at}"          # vd "EGLL|2025-12-31T23:50:00Z"

def _pack_record(row):       # gói 5 giá trị đo vào 1 tuple
    return (wind_kt, visibility_m, ceiling_ft, temp_c, altimeter_hpa)

def _unpack_record(key, values):   # làm ngược lại: từ khoá + tuple → dict đầy đủ
    station, _, observed_at = key.partition("|")
```
`"A|B".partition("|")` → `("A", "|", "B")`.
Dấu `_` ở giữa là bỏ qua phần dấu `|`. Tên hàm bắt đầu bằng `_` là quy ước "hàm nội bộ".

> Tại sao nhận dạng bằng `(station, observed_at)`? Vì README nói: *"identity của 1 báo cáo là sân bay + giờ quan trắc, không phải dòng log nó đến từ đâu"*.

### 7.2 `deduplicate_records(rows)`
Giữ bản cuối cùng cho mỗi khoá (last-write-wins). **Lưu ý:** hàm này được định nghĩa nhưng **`Handler.process` không hề gọi nó** – nó là đoạn code thừa.

---

## 8. Class `Handler` – trung tâm điều khiển

```python
class Handler:
    def __init__(self):
        self.output_rows = None
        self.records_map = {}
```
`records_map` là **bộ nhớ**: `{ "EGLL|2025-12-31T23:50:00Z": (5, 9999, 1500, "-2.0", "1013.0"), ... }`

### `process(self, raw)` – chạy cho **mỗi dòng log**
```python
rows = normalize_rows(raw)          # Giai đoạn 1
extracted = extract_columns(rows)   # Giai đoạn 2

out = []
for row in extracted:
    key = _record_key(row)
    if key is None: continue
    values = _pack_record(row)
    if self.records_map.get(key) == values:
        continue                    # giống hệt bản đã gửi → bỏ
    self.records_map[key] = values  # nhớ lại
    out.append(row)                 # gửi đi
return out
```
**Logic cốt lõi:**
- Khoá **chưa từng thấy** → gửi đi.
- Khoá đã thấy, giá trị **giống hệt** → bỏ (đúng ý "same line sent twice").
- Khoá đã thấy, giá trị **khác** → **gửi lại 1 dòng mới** (coi là bản sửa).

Mình đã thử gửi cùng 1 dòng 2 lần: lần 1 ra 1 dòng, lần 2 ra `[]`.

### `finalize(self)`
```python
return []
```
Không trả gì thêm, vì mọi thứ đã được trả trong `process`.

### Hai method `extract_columns` và `deduplicate`
Hai method này nằm trong class nhưng **`process` không dùng**. Có vẻ là phần dư để giữ giao diện, bạn có thể bỏ qua khi đọc.

---

## 9. Ví dụ chạy từ đầu đến cuối

Đầu vào:
```json
{"feed":"relay","ts":"1767225600","msg":"METAR EGLL 312350Z 34005KT 9999 BKN015 M02/M04 Q1013="}
```

| Bước | Kết quả |
|---|---|
| `parse_raw` | dict `{"feed": "relay", "ts": "1767225600", "msg": "METAR ..."}` |
| `flatten` | giữ nguyên (không lồng) |
| `to_canonical` | `msg`→`report`, `ts`→`received_at`, `feed` bị bỏ |
| `clean_report` | `"METAR EGLL 312350Z 34005KT 9999 BKN015 M02/M04 Q1013"` (đã bỏ `=`) |
| `clean_timestamp` | `"2026-01-01T00:00:00Z"` (từ epoch) |
| `extract_station` | `EGLL` |
| `extract_observed_at` | `2025-12-31T23:50:00Z` (ngày 31 → tháng 12 năm trước) |
| `extract_wind_kt` | `5` |
| `extract_visibility_m` | `9999` |
| `extract_ceiling_ft` | `1500` |
| `extract_temp_c` | `"-2.0"` |
| `extract_altimeter_hpa` | `"1013.0"` |

Ví dụ kiểu Mỹ:
```
KJFK 011251Z 18012G20KT 1 1/2SM OVC008 05/M01 A3001 RMK T00501011
```
→ gió 12, tầm nhìn 2414 m, trần mây 800 ft, nhiệt độ `5.0`, áp suất `1016.3`. (Mình đã chạy thật, đúng như vậy.)

---

## 10. Cách đọc file này khi bị lạc

1. Tìm class `Handler.process` (cuối file) → xem 2 dòng đầu: `normalize_rows` và `extract_columns`.
2. Muốn biết **cột nào sai** → vào đúng hàm `extract_<tên cột>` (mỗi cột đúng 1 hàm).
3. Muốn biết **dòng nào bị bỏ** → xem `normalize_rows` (thiếu report/thời gian) và `extract_columns` (thiếu station/observed_at).
4. Đọc `README.md` của tuần (bảng "What the stream held") để biết mỗi lỗi dữ liệu ứng với hàm nào.

---

## 11. Đối chiếu với README: chỗ nào code chưa xử lý

Đây là phần "nhìn lại" dựa trên bảng điểm của README (mục *Handled = no*) và đọc code:

| Lỗi dữ liệu | Quan sát trong code |
|---|---|
| **Giá trị gõ tách đôi** (`30007 KT`, `10 SM`, `BKN 015`) | Code tách theo dấu cách và regex liền nhau, nên các nhóm bị tách rời không khớp |
| **Đơn vị gõ tay** (`KTS`, `10KM`, `QNH1013`, `A30.01`) | `WIND_RE` chỉ nhận `KT/MPS/KMH`; chỉ có nhóm `A\d{4}` và `Q\d{4}`; không có `KM`/`QNH` |
| **Thiếu chữ Z** (`311851`) | `OBSERVATION_TIME_RE` và regex giờ đều bắt buộc có `Z` → README ghi recovered 0% |
| **Heading bản tin** (`SAUS70 KWBC 311900`) | Code không bỏ dòng này trước khi đọc |
| **Dòng bị chia 2 log line** | Mỗi dòng xử lý độc lập, chưa ghép dòng tiếp theo |
| **Chữ `O` thay số `0`** (`BKNO15`) | Chưa sửa `O` → `0` |
| **`2400`** | `hour > 23` → trả `None` → 0% |
| **Trùng và sửa lỗi** | Bản sửa (giá trị khác) bị gửi thành 1 dòng thứ hai cho cùng khoá; README tính đây là dòng "second row for a key already emitted" |

Đây chỉ là gợi ý nơi để cải tiến sau này; chưa cần hiểu hết ngay.

---

## 12. Tóm tắt 1 phút

- File chia 2 việc: **(1) làm sạch JSON bẩn → `report` + `received_at`**, **(2) đọc mã METAR → 7 cột**.
- Mỗi cột có **1 hàm riêng**; hầu hết dùng **regex + đổi đơn vị + `try/except`**.
- `Handler` nhớ những gì đã gửi bằng `records_map` để **không gửi trùng**.
- Mọi lỗi đều bị bắt, trả `None`/`[]` nên chương trình không bao giờ sập trên dữ liệu bẩn.
