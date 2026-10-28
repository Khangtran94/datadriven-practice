# Giải thích từng CTE của `gold_submit.sql` (tuần 5, The Close)

Đọc từ trên xuống. Mỗi khối có 3 ý: **Làm gì** (vì sao cần), **Trước → Sau**, **Đưa đi đâu**.
Số dòng là dòng trong `gold_submit.sql` (306 dòng).

## Bức tranh lớn (đọc phần này trước)

Bài toán: công ty thanh toán thẻ đóng sổ. Mỗi đêm một job copy thay đổi từ database sang 3 bảng thô, và các bảng này **chỉ nhớ vài đêm gần nhất**:

| Bảng thô | Nhớ bao lâu |
|---|---|
| `raw_payments` | 7 đêm gần nhất |
| `raw_fx_rates` | 2 đêm gần nhất |
| `raw_merchants` | chỉ bản copy mới nhất |

Cần ra bảng `fct_payments`, **mỗi giao dịch một dòng**, tiền quy ra USD.

Gold chia thành 4 task. 3 task đầu **lưu lịch sử qua các đêm** (vì dữ liệu thô bị quên), task cuối **tính toán**.

```
raw_payments  --> payments_history --+
raw_fx_rates  --> fx_history ---------+--> fct_payments
raw_merchants --> merchants_history --+
```

`fct_payments` có `trigger_rule: all_done` (dòng 22): nó vẫn chạy dù một task history bị lỗi.

**Ba việc lặp lại trong cả file, hiểu một lần là hiểu hết:**

1. **Cột `rk`** = nối tất cả cột thô của một dòng bằng `quote(...) || '|'`. Đây là "dấu vân tay" của dòng nguồn; là `unique_key` để merge, nên chạy lại cùng dữ liệu không sinh dòng trùng.
2. **Làm sạch chữ trống**: cắt khoảng trắng, rồi các từ như `''`, `\N`, `null`, `none`, `n/a`, `nan`, `-`, `?`... thành NULL thật.
3. **Thủ thuật "khóa + giá trị"**: `substr(max(khóa || giá_trị), độ_dài_khóa + 1)`. Khóa là chuỗi thời gian nên `max` chọn giá trị **mới nhất**.

**Ví dụ dùng xuyên suốt** (từ sample trong tài liệu): giao dịch `pay_ps8ppu1l`, tiền JPY, số tiền thô `3463`. Có hai đêm trả tiền (settled) `1522` rồi `1941`. Kết quả mong đợi: `amount_usd = 23.37`, `settled_usd = 23.37`.

---

# TASK 1: `payments_history` (dòng 26-121)

Nhật ký thay đổi của giao dịch, đã làm sạch, **giữ qua các đêm**. Chưa gộp dòng: mỗi dòng nguồn khác nhau là một dòng.

### CTE `c` (27-44)
- **Làm gì:** tạo `rk` (dòng 29). Với mỗi cột, cắt khoảng trắng (cả tab, xuống dòng) và biến chữ trống thành NULL. Đổi tên 3 cột kỹ thuật: `_batch_id` thành `bid`, `_correction_for` thành `cfor`, `_loaded_at` thành `lat`.
- **Trước → Sau:** `' \N '` thành NULL. `' pay_AB12 '` thành `pay_AB12`.
- **Đưa đi đâu:** `t`.

### CTE `t` (45-56)
- **Làm gì:** chuẩn bị chữ để parse.
  - 4 cột giờ (`created_at`, `captured_at`, `updated_at`, `lat`) thành `cr`, `ca`, `up`, `lo`: in hoa, bỏ `UTC` và `GMT`, đổi chữ `T` thành dấu cách.
  - `metadata` (JSON): `mj` là JSON hợp lệ; nếu cả cột bị bọc thành một chuỗi (JSON được mã hóa hai lần) thì mở lớp ngoài ra. `mrest` là phần chữ nằm sau `"order_ref"`, dùng khi JSON bị cắt hỏng (cột chỉ rộng 40 ký tự).
- **Trước → Sau:** `2026-09-20T17:29:33 UTC` thành `2026-09-20 17:29:33`. `{"order_ref": "ORD-93` (cụt) thì `mj` NULL, `mrest` = `"ORD-93`.
- **Đưa đi đâu:** `p`.

### CTE `p` (57-90)
- **Làm gì:** parse 4 cột giờ về dạng `YYYY-MM-DD HH:MM:SS` (UTC).
  - Toàn chữ số: epoch. Từ `1e11` trở lên là mili giây (chia 1000); từ `1e8` trở lên là giây; nhỏ hơn thì NULL.
  - Có múi giờ `+HH`: thêm `:00`. `+HHMM`: chèn dấu `:`. Còn lại để `datetime()` đọc.
  - `order_ref`: nếu `mj` là object và có `order_ref` (chữ hoặc số) thì lấy. Nếu không, đọc từ `mrest`: bắt đầu bằng `"` thì lấy đến dấu `"` kế tiếp, không thì lấy đến dấu `,` hoặc `}`.
- **Trước → Sau:** `1758387000000` (mili giây) thành `2025-09-20 ...`. `{"order_ref":"ORD-9385051"}` thành `ORD-9385051`.
- **Đưa đi đâu:** `d`.

### CTE `d` (91-100)
- **Làm gì:** lấy **ngày** từ `bid` (`batch_day`) và từ `cfor` (`corr_day`), chấp nhận 3 kiểu viết: `2026-09-20...`, `20260920`, `2026/09/20...`.
- **Trước → Sau:** `20260920` thành `2026-09-20`.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (101-121): chuẩn hóa cuối
- `pid`: chữ thường.
- `mid` (mã merchant): chuẩn về `M` + 6 chữ số. Mã bị mất số 0 đầu (`50484`) thì bổ sung thành `M050484`.
- `status_n`: ánh xạ về `authorized`, `captured`, `failed`, `voided`, `disputed` (có cả cách viết Anh `authorised`). Từ lạ thì NULL.
- `amt`, `stl` (số tiền, số đã thanh toán): chỉ nhận chuỗi số hợp lệ (chữ số, tối đa một dấu `.`, dấu `-` chỉ ở đầu). **Giữ dạng chữ**, vì còn cần biết có dấu `.` hay không (xem task 4).
- `cur`: đúng 3 chữ cái, in hoa.
- 4 cột giờ: chỉ nhận nếu nằm trong 1990 đến 2100.
- `order_ref`: bỏ chuỗi rỗng, `null`, `none`.
- `eff_day` (ngày mà dòng này tính cho): ưu tiên `corr_day` (ngày được sửa), rồi `batch_day`, cuối cùng là ngày load trừ 1.
- **Đưa đi đâu:** `fct_payments` (mọi CTE đầu của task 4).

---

# TASK 2: `fx_history` (dòng 123-153)

Tỷ giá theo (tiền tệ, ngày), **giữ qua các đêm**.

### CTE `c` (124-134)
- **Làm gì:** tạo `rk`; làm sạch chữ trống; riêng tỷ giá đổi dấu phẩy thập phân thành chấm. Giờ load làm sạch như `t` ở task 1.
- **Trước → Sau:** `'0,0067'` thành `'0.0067'`.
- **Đưa đi đâu:** `p`.

### CTE `p` (135-152)
- **Làm gì:** `cur` đúng 3 chữ cái. `rate_day`: ưu tiên ngày trong cột `rate_date` (3 kiểu viết), nếu không có thì lấy ngày của batch. `rate` phải là số hợp lệ lớn hơn 0. Giờ load parse như task 1.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (153)
Chọn `rk, cur, rate_day, rate, loaded_ts`. **Đưa đi đâu:** `fx1`.

---

# TASK 3: `merchants_history` (dòng 155-183)

Lịch sử thông tin merchant (quốc gia, có phải merchant test không). Bảng thô chỉ giữ bản mới nhất nên đây là nơi duy nhất giữ trạng thái cũ.

### CTE `c` (156-166)
- **Làm gì:** tạo `rk`; làm sạch mã merchant, batch, giờ load; `country` in hoa; `is_test` chữ thường.
- **Đưa đi đâu:** `p`.

### CTE `p` (167-182)
- **Làm gì:** `mid` chuẩn như task 1. `country` đúng 2 chữ cái. `is_test` thành 1 (`t`, `true`, `1`, `y`, `yes`) hoặc 0 (`f`, `false`, `0`, `n`, `no`), khác thì NULL. `bday` lấy từ batch. Giờ load parse.
- **Trước → Sau:** `'Yes'` thành `is_test = 1`. `'de'` thành `DE`.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (183)
`batch_day = coalesce(bday, ngày load trừ 1)`. **Đưa đi đâu:** `m1`.

---

# TASK 4: `fct_payments` (dòng 185-306)

Bảng đích, mỗi giao dịch một dòng. Đây là task dài nhất, chia theo 3 nhánh: **giao dịch** (p, g, sd, gd, st), **tỷ giá** (fx1, fxm, fx2, fx3), **merchant** (m1, mc, mt, mf), rồi ghép (j, v).

## Nhánh giao dịch

### CTE `p` (186-191)
- **Làm gì:** từ `payments_history`, chỉ giữ `pid` đúng dạng `pay_` + 8 ký tự. Tạo khóa sắp xếp `k` gồm `eff_day` (10) + giờ load (19) + giờ cập nhật (19) = **48 ký tự**.
- **Đưa đi đâu:** `g`, `sd`.

### CTE `g` (192-204)
- **Làm gì:** gom theo `pid`. Mỗi cột lấy giá trị **mới nhất khác NULL** bằng thủ thuật khóa + giá trị (`substr(..., 49)`).
  - `amt`, `cur`, `created_ts`, `mid`, `order_ref`: mới nhất khác NULL.
  - `status`: lấy từ dòng mới nhất, **kể cả khi nó trống** (trạng thái là "hiện tại thế nào").
  - `cap_last`: `captured_ts` của dòng mới nhất (có thể NULL). `cap_any`: `captured_ts` mới nhất khác NULL.
- **Trước → Sau:** 5 dòng thô của một giao dịch thành 1 dòng.
- **Đưa đi đâu:** `gd`.

### CTE `sd` (205-211)
- **Làm gì:** số tiền đã thanh toán (`stl`) cho từng (giao dịch, ngày): lấy giá trị mới nhất của **ngày đó** (theo giờ load, giờ cập nhật). Một ngày bị gửi hai lần thì chỉ tính một lần.
- **Trước → Sau (ví dụ):** ngày A có `1522` (gửi 2 lần giống nhau), ngày B có `1941` thì ra 2 dòng: `1522` và `1941`.
- **Đưa đi đâu:** `st`.

### CTE `gd` (212-219)
- **Làm gì:** thêm `dv` (số đơn vị nhỏ trong 1 đơn vị tiền): `1` cho tiền không có số lẻ (JPY, KRW, VND...), `1000` cho tiền 3 số lẻ (BHD, KWD...), còn lại `100`. Thêm `cday` = ngày tạo giao dịch.
- **Trước → Sau:** `cur = JPY` thành `dv = 1`. `cur = USD` thành `dv = 100`.
- **Đưa đi đâu:** `st`, `j`.

### CTE `st` (220-227)
- **Làm gì:** cộng số đã thanh toán theo giao dịch. Số có dấu `.` là đơn vị lớn (ví dụ `15.20`), nhân với `dv` rồi làm tròn để về đơn vị nhỏ; số không có dấu `.` đã là đơn vị nhỏ. `st_all` cộng mọi ngày. `st_in` chỉ cộng các ngày `eff_day` từ `2026-02-02` đến `2026-02-26`.
- **Trước → Sau (ví dụ JPY):** `1522 + 1941 = 3463` (`st_all`).
- **Đưa đi đâu:** `j`.
- **Lưu ý:** khoảng `2026-02-02` đến `2026-02-26` (dòng 223) không khớp ngày trong tài liệu (dữ liệu chạy từ 2026-09-18, đóng sổ đến 2026-10-12). Tài liệu cũng không nêu rõ khoảng "kỳ đóng sổ". Mình không biết vì sao gold chọn khoảng này, nên không khẳng định gì ở đây.

## Nhánh tỷ giá

### CTE `fx1` (228-235)
- **Làm gì:** mỗi (tiền tệ, ngày) chỉ giữ **một** tỷ giá, bản mới nhất theo giờ load (`rn = 1`). Tỷ giá gửi lại thay thế bản trước (theo ghi chú của finance).
- **Đưa đi đâu:** `fxm`, `fx2`.

### CTE `fxm` (236-241)
- **Làm gì:** tính **trung vị** tỷ giá của mỗi tiền tệ (dòng ở giữa khi sắp xếp), làm mốc so sánh.
- **Đưa đi đâu:** `fx2`.

### CTE `fx2` (242-247)
- **Làm gì:** kiểm tra từng tỷ giá so với trung vị. Nếu nằm trong khoảng 0.9 đến 1.11 lần trung vị thì giữ. Nếu **nghịch đảo** của nó nằm trong khoảng đó (tỷ giá bị viết ngược chiều) thì dùng `1/rate`. Ngoài hai trường hợp thì NULL (loại).
- **Trước → Sau:** trung vị `0.0067`, một dòng `148.0` thành `0.00676`. Một dòng `5.0` thành NULL.
- **Đưa đi đâu:** `fx3`.

### CTE `fx3` (248-251)
- **Làm gì:** với mỗi tỷ giá hợp lệ, thêm `next_day` = ngày của tỷ giá kế tiếp. Mỗi tỷ giá có hiệu lực từ `rate_day` đến trước `next_day`. Ngày không có tỷ giá thì dùng tỷ giá gần nhất phía trước, đúng yêu cầu của finance.
- **Đưa đi đâu:** `j`.

## Nhánh merchant

### CTE `m1` (252-259)
- **Làm gì:** mỗi (merchant, ngày batch) giữ một dòng mới nhất.
- **Đưa đi đâu:** `mc`, `mt`, `mf`.

### CTE `mc` (260-263)
- **Làm gì:** các đoạn hiệu lực của **quốc gia** merchant (từ `batch_day` đến trước `next_day`), chỉ dùng dòng có quốc gia.
- **Đưa đi đâu:** `j`.

### CTE `mt` (264-267)
- **Làm gì:** như `mc` nhưng cho cờ **test**.
- **Đưa đi đâu:** `j`.

### CTE `mf` (268-274)
- **Làm gì:** dự phòng cho merchant không có đoạn nào bao phủ ngày giao dịch: số quốc gia khác nhau từng có (`n_country`), quốc gia đầu tiên, cờ test đầu tiên.
- **Đưa đi đâu:** `j`.

## Ghép và tính

### CTE `j` (275-288)
- **Làm gì:** nối mọi thứ vào `gd`, theo **ngày tạo giao dịch** `cday`.
  - `rate`: tỷ giá hiệu lực vào `cday`; nếu không có và tiền là USD thì `1.0`.
  - `country`: quốc gia hiệu lực vào `cday`; nếu không có thì quốc gia đầu tiên, nhưng **chỉ khi merchant chỉ từng có một quốc gia**.
  - `is_test`: cờ hiệu lực vào `cday`; nếu không có thì cờ đầu tiên; nếu vẫn không thì 0.
  - `st_all`, `st_in`: từ `st`, thiếu thì 0.
- **Đưa đi đâu:** `v`.

### CTE `v` (289-295)
- **Làm gì:** tính tiền thô quy ra USD.
  - `amount_raw`: số tiền thô; nếu có dấu `.` (đơn vị lớn) thì giữ, nếu không (đơn vị nhỏ) thì chia `dv`; rồi nhân `rate`.
  - `settled_raw = st_all / dv * rate`, `in_raw = st_in / dv * rate`.
- **Trước → Sau (ví dụ):** `3463 JPY` chia 1, nhân tỷ giá thì ra khoảng `23.37`.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (296-306): bảng đích
- Làm tròn 2 chữ số, nửa ra xa số 0 (cộng hoặc trừ `1e-9` trước khi làm tròn để tránh sai số số thực).
- `captured_at`: dùng `cap_last`; nếu trống và trạng thái là `captured` hoặc `disputed` thì dùng `cap_any`. Ghép thành `YYYY-MM-DDTHH:MM:SSZ`.
- **Loại merchant test** (`WHERE is_test = 0`).
- **Đưa đi đâu:** đây là kết quả cuối.

---

## Ví dụ xuyên suốt, từng bước

| Bước | Giá trị |
|---|---|
| Thô | `pay_ps8ppu1l`, `M050484`, amount `3463`, `JPY`, settled `1522` (đêm 1) và `1941` (đêm 2) |
| `payments_history` | `pid`, `mid`, `amt = 3463` (vẫn là chữ), `stl = 1522` và `1941` ở hai dòng, `eff_day` mỗi dòng |
| `g` | `amt = 3463`, `cur = JPY`, `status = captured`, `cap_last` |
| `sd` | hai dòng: `1522` (ngày A), `1941` (ngày B) |
| `gd` | `dv = 1` (JPY không có số lẻ) |
| `st` | `st_all = 3463` |
| `fx3` + `j` | tỷ giá JPY hiệu lực vào ngày tạo |
| `v` | `amount_raw = 3463 / 1 * rate` |
| `fct_payments` | `amount_usd = 23.37`, `settled_usd = 23.37` |

## 3 điều cần nhớ

1. **Làm sạch một lần ở 3 task đầu**, rồi `fct_payments` đọc dữ liệu đã sạch. Mỗi bảng thô dùng chung bộ quy tắc cho mọi cột.
2. **Tỷ giá, quốc gia, cờ test đều là "đoạn hiệu lực"** (`lead()` + so sánh ngày), không phải giá trị hiện tại. Giao dịch dùng giá trị của **ngày tạo**.
3. **Tiền thanh toán tính theo ngày rồi cộng**, mỗi ngày chỉ lấy một giá trị mới nhất, và phải biết đơn vị (có dấu `.` hay không, tiền có mấy số lẻ) trước khi nhân tỷ giá.
