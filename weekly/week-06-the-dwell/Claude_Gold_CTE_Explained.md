# Giải thích từng CTE của `gold_submit.sql` (tuần 6, The Dwell)

Đọc từ trên xuống. Mỗi khối có 3 ý: **Làm gì**, **Trước → Sau**, **Đưa đi đâu**.
Số dòng là dòng trong `gold_submit.sql`.

## Bức tranh lớn (đọc phần này trước)

Bài toán: mỗi đêm có 3 bảng thô. Cần ra 1 bảng `storage_charges`, **mỗi container (visit) một dòng**, có tiền lưu bãi.

Gold chia thành 9 task. 3 task đầu **lưu lịch sử qua các đêm** (vì dữ liệu thô bị quên), 6 task sau **tính toán**.

```
unit_visit    -> unit_visit_history  --+--> visits_latest --+--> visit_lines <-- line_operator_history <-- line_operator
tariff_rate   -> tariff_rate_history    |                    |
                                        +--> visit_days --> tariff_day_rates <-- tariff_rate_history
                                                 |
                                                 +--> visit_charges --> storage_charges
```

Thứ tự chạy thật: 3 bảng history, `visits_latest`, `visit_days`, `tariff_day_rates`, `visit_charges`, `visit_lines`, `storage_charges`.

**Một ví dụ dùng xuyên suốt.** Một container, dòng thô như sau:
- `visit_gkey = ' 12345678 '`, `visit_state = 'Gate-Out'`, `days_chg = '1.0'`
- giờ cập nhật `2026-10-01 03:30:00+0530`, mã giá `std1`

Cuối cùng nó thành: `visit_gkey = 12345678`, `visit_state = gated_out`, tiền `14.72`.

**Ý tưởng cốt lõi của gold:** làm sạch **mọi cột bằng cùng một bộ quy tắc** ở task đầu tiên, rồi mới xếp hạng và nối bảng.

---

# TASK 1: `unit_visit_history` (dòng 58-164)

Nhật ký thay đổi của từng container, đã làm sạch, **giữ lại qua các đêm**.
Không gộp dòng ở đây: mỗi dòng nguồn khác nhau là một dòng.

### CTE `s` (58-70)
- **Làm gì:** cắt khoảng trắng; biến `NULL`, `\N`, `N/A`, `-`... thành NULL thật. Tạo `src_key` bằng cách nối 9 cột thô. Khi chạy tăng dần (incremental), nó bỏ ngay dòng đã có trong bảng lưu, trước khi tốn công làm sạch.
- **Trước → Sau:** `' 12345678 '` thành `12345678`. `'\N'` thành NULL.
- **Đưa đi đâu:** `t`.

### CTE `t` (71-128)
- **Làm gì:** chuẩn hóa từng cột.
  - `visit_gkey`: chỉ nhận chuỗi toàn chữ số, hoặc dạng `123.0` (cắt `.0`). Khác thì NULL.
  - `unit_c`: bỏ dấu cách, `-`, `_`, `.`, in hoa.
  - `state_norm`: chữ thường, dấu cách và `-` thành `_`.
  - `days`: thành số thực (nên `1.0`, `1.5` đều được).
  - 4 cột giờ: đưa về dạng `2026-10-01T03:30:00Z` (UTC). Xử lý: epoch 13 chữ số (mili giây), epoch 10 chữ số (giây), `+HH`, `+HHMM`, `+HH:MM`, hậu tố ` UTC`, `Z`. Giờ không có múi giờ thì coi là giờ cảng (+08:00); riêng giờ load coi là UTC.
  - `batch_day`, `rest_day`: lấy ngày từ `_batch_id`, `_restated_day`.
- **Trước → Sau (ví dụ):** `2026-10-01 03:30:00+0530` thành `2026-09-30T22:00:00Z`.
- **Đưa đi đâu:** `k`.

### CTE `k` (129-135)
- **Làm gì:** bỏ dòng không có `visit_gkey` hợp lệ (không biết là container nào thì vô dụng). Tìm vị trí chữ `"booking_ref"` hoặc `"bookingRef"` trong cột `remarks`, dùng cho trường hợp JSON bị cắt cụt.
- **Trước → Sau:** thêm cột `kpos` = vị trí ngay sau tên khóa (hoặc NULL).
- **Đưa đi đâu:** `q`.

### CTE `q` (136-140)
- **Làm gì:** từ `kpos`, bỏ khoảng trắng, kiểm tra ký tự tiếp theo là `:`, rồi lấy phần sau dấu `:`.
- **Trước → Sau:** `{"booking_ref": "BK-12` thành `qv = "BK-12`.
- **Đưa đi đâu:** `b`.

### CTE `b` (141-143)
- **Làm gì:** nếu giá trị bắt đầu bằng dấu `"` thì bỏ dấu mở, giữ phần thân.
- **Trước → Sau:** `qv = "BK-1234567", ...` thành `body = BK-1234567", ...`.
- **Đưa đi đâu:** `e`.

### CTE `e` (144-154)
- **Làm gì:** hoàn tất các cột nghiệp vụ.
  - `unit_nbr`: chỉ giữ dạng 4 chữ cái + 7 chữ số.
  - `eff_day` (ngày tính phí của dòng): ưu tiên `rest_day`, rồi `batch_day`, cuối cùng là ngày load trừ 1.
  - `restated`: bằng 1 nếu dòng này **ghi đè** một ngày đã tính trước đó.
  - `ref_raw` (mã đặt chỗ): nếu `remarks` là JSON hợp lệ thì lấy `booking_ref` hoặc `bookingRef`. Nếu JSON bị cắt thì lấy phần nằm giữa hai dấu `"` của `body`. Cách này không làm cả task bị lỗi khi gặp JSON hỏng.
- **Đưa đi đâu:** `d`.

### CTE `d` (155-160)
- **Làm gì:** biến các marker kiểu `N/A`, `UNKNOWN`, `--`, `?` của mã đặt chỗ thành NULL. Đánh số `rn` để mỗi `src_key` chỉ giữ **một** dòng (dòng có giờ load mới nhất). Xử lý trường hợp cùng một dòng bị ghi hai lần.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (161-164)
Giữ `rn = 1` và `eff_day` khác NULL. Bảng này được dùng bởi `visits_latest` và `visit_days`.

---

# TASK 2: `tariff_rate_history` (dòng 169-201)

Giá theo (mã giá, ngày hiệu lực), **giữ qua các đêm** vì landing chỉ nhớ 2 đêm.

### CTE `n` (169-184)
- **Làm gì:** làm sạch. Mã giá in hoa, ngày hiệu lực thành ngày. Xử lý giá: `12,50` thành `12.50` (dấu phẩy thập phân); `1,234.50` bỏ dấu phẩy hàng nghìn; bỏ ký hiệu `$`. Giờ load parse như task 1.
- **Trước → Sau:** `'$1,234.50'` thành `'1234.50'`.
- **Đưa đi đâu:** `c`.

### CTE `c` (185-189)
- **Làm gì:** chỉ giữ dòng có giá toàn chữ số và dấu chấm, mã giá và ngày hiệu lực không NULL. Rồi đổi giá sang số.
- **Trước → Sau:** dòng giá rỗng hoặc có chữ bị loại.
- **Đưa đi đâu:** `d`.

### CTE `d` (190-192)
- **Làm gì:** nếu một giá bị đăng sai rồi đăng lại cho cùng ngày hiệu lực, chỉ giữ bản **mới nhất**.
- **Trước → Sau:** hai dòng cùng (STD1, 2026-10-01) giá 14.0 và 14.72 thì chỉ dòng 14.72 có `rn = 1`.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (193-201)
Khi chạy tăng dần: chỉ ghi nếu cặp chưa có, hoặc giờ load mới hơn hoặc bằng bản đã lưu. Bảng này dùng bởi `tariff_day_rates`.

---

# TASK 3: `line_operator_history` (dòng 206-244)

Lịch sử trạng thái của **hãng tàu**: ai trả tiền (`bill_to`) và có phải hãng test không. Landing chỉ giữ bản chụp mới nhất, nên đây là nơi duy nhất giữ trạng thái cũ.

### CTE `m` (206-222)
- **Làm gì:** làm sạch. Mã hãng in hoa. `snap_day` là ngày của batch. `bill_to` in hoa, marker thành NULL. `test_flag` thành 1 (Y, YES, TRUE, 1, T), 0 (N, NO, FALSE, 0, F) hoặc NULL.
- **Trước → Sau:** `'yes'` thành `is_test = 1`. `'-'` thành `bill_to = NULL`.
- **Đưa đi đâu:** `d`.

### CTE `d` (223-227)
- **Làm gì:** mỗi (hãng, ngày chụp) giữ một dòng mới nhất. Bỏ dòng thiếu mã hãng hoặc thiếu ngày.
- **Đưa đi đâu:** `cur` (nếu chạy tăng dần) và SELECT cuối.

### CTE `cur` (228-235, chỉ khi chạy tăng dần)
- **Làm gì:** lấy trạng thái đã lưu **mới nhất** của mỗi hãng.
- **Trước → Sau:** từ nhiều dòng lịch sử còn một dòng mỗi hãng.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (236-244)
Chỉ ghi nếu hãng mới, hoặc `bill_to` hay `is_test` **khác** trạng thái mới nhất đã lưu. Tức bảng chỉ lưu **các lần thay đổi**, không lưu đêm nào cũng giống nhau. Dùng bởi `visit_lines`.

---

# TASK 4: `visits_latest` (dòng 250-278)

**Mỗi container một dòng.** Mỗi cột lấy giá trị **mới nhất mà không NULL** (vì dòng mới nhất thường thiếu cột mà dòng cũ còn giữ).

### CTE `g` (250-257)
- **Làm gì:** gom theo `visit_gkey`. Mỗi cột dùng một thủ thuật: ghép **khóa sắp xếp 50 ký tự** + giá trị rồi lấy `max`. Khóa gồm giờ cập nhật (20 ký tự) + ngày batch (10) + giờ load (20), nên giá trị có khóa lớn nhất là giá trị mới nhất. `first_day` là ngày tính phí nhỏ nhất của container.
- **Trước → Sau:** nhiều dòng của một container thành một dòng, các cột `m_unit`, `m_line`, `m_state`, `m_tariff`, `m_dsch`, `m_gate`, `m_book` (mỗi cột là khóa + giá trị dính liền).
- **Đưa đi đâu:** `v`.

### CTE `v` (258-264)
- **Làm gì:** cắt bỏ 50 ký tự khóa, chỉ giữ giá trị.
- **Trước → Sau:** `2026-10-01T...Z2026-10-012026-10-01T...ZOOG1` thành `OOG1`.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (265-278)
Chuyển nhiều cách viết trạng thái (`dischgd`, `unloaded`, `gate_out`, `exited`, `ts`...) về **4 trạng thái chuẩn**: `discharged`, `held`, `gated_out`, `transshipped`. Từ lạ thì NULL. Dùng bởi `visit_days`, `visit_lines`, `storage_charges`.

---

# TASK 5: `visit_lines` (dòng 284-307)

Với mỗi container, tìm **hãng tàu và bên thanh toán đúng vào ngày dỡ hàng**, không phải trạng thái hôm nay.
Cách làm: đưa snapshot và container vào cùng một dòng thời gian, rồi lấy snapshot gần nhất phía trước.

### CTE `base` (284-288)
- **Làm gì:** tính **ngày cảng** `d` của mỗi container: giờ dỡ hàng (UTC) cộng 2 giờ rồi lấy ngày. Ngày cảng cắt lúc 06:00 giờ cảng (UTC+8), tức 22:00 UTC. Không có giờ dỡ hàng thì dùng `first_day`.
- **Trước → Sau:** `dsch_utc = 2026-10-01T23:00:00Z` thì `d = 2026-10-02`.
- **Đưa đi đâu:** `evs`.

### CTE `snaps` (289-293)
- **Làm gì:** lấy các lần đổi trạng thái của những hãng có trong `base`. Mỗi dòng là sự kiện loại `ord = 0` tại ngày `snap_day`.
- **Đưa đi đâu:** `u`.

### CTE `evs` (294)
- **Làm gì:** biến mỗi container thành sự kiện loại `ord = 1` tại ngày `d`.
- **Đưa đi đâu:** `u`.

### CTE `u` (295)
- **Làm gì:** gộp hai loại sự kiện thành một dòng thời gian cho mỗi hãng.
- **Đưa đi đâu:** `w`.

### CTE `w` (296-302)
- **Làm gì:** sắp xếp theo (ngày, loại), snapshot đứng trước container nếu cùng ngày. `asof_d` = ngày snapshot gần nhất tính đến dòng hiện tại. `first_d` = ngày snapshot sớm nhất của hãng, dùng dự phòng cho container dỡ hàng trước khi có snapshot nào.
- **Trước → Sau:** container ngày 10-15, snapshot ngày 10-01 và 10-12 thì `asof_d = 10-12`.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (303-307)
Nối với `line_operator_history` theo `COALESCE(asof_d, first_d)`, chỉ lấy các dòng container. Kết quả: (`visit_gkey`, `bill_to`, `is_test`). Dùng bởi `storage_charges`.

---

# TASK 6: `visit_days` (dòng 314-326)

Mỗi dòng = **một container, một ngày tính phí**: số ngày bị tính và mã giá của ngày đó.

### CTE `g` (314-320)
- **Làm gì:** gom theo (container, ngày tính phí). Dùng thủ thuật khóa + giá trị như task 4: khóa gồm `restated` (0 hoặc 1) + giờ cập nhật + giờ load. Vì vậy dòng **có `restated = 1` luôn thắng** dòng cũ của cùng ngày, và giữa các dòng cùng loại thì dòng mới nhất thắng. Nhờ đó ngày bị tính lại được **thay thế, không bị cộng hai lần**.
- **Trước → Sau:** ngày 10-18 có 2 dòng (1 ngày, và một dòng restated 2 ngày) thì giữ dòng restated.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (321-326)
Cắt khóa để lấy số ngày. Mã giá lấy của dòng đó; nếu không có thì dùng mã giá mới nhất của container (từ `visits_latest`). Bỏ ngày không có số ngày. Dùng bởi `tariff_day_rates` và `visit_charges`.

---

# TASK 7: `tariff_day_rates` (dòng 341-348)

Giá của **từng ngày** mà các container cần, tính bằng phần mười nghìn đô (số nguyên).

### CTE `pairs` (341-343)
- **Làm gì:** lấy danh sách (mã giá, ngày) cần tra, không trùng, để mỗi cặp chỉ tra một lần.
- **Đưa đi đâu:** SELECT cuối.

### SELECT cuối (344-348)
Với mỗi cặp, lấy giá của **ngày hiệu lực lớn nhất mà không vượt quá ngày đang xét** (giá áp dụng cho đến khi có giá mới). Nhân 10,000 rồi làm tròn thành số nguyên, để cộng không bị sai số số thực. Dùng bởi `visit_charges`.

---

# TASK 8: `visit_charges` (dòng 331-336, không có CTE)

- **Làm gì:** tính tiền. Nối `visit_days` với `tariff_day_rates`. Tiền mỗi ngày = `số ngày x giá` (đơn vị 1/10,000 đô), làm tròn.
- **Trước → Sau:** cộng theo container được `tot_i` (tổng). `per_i` chỉ cộng các ngày `<= 2026-10-19` (phần trong kỳ đóng sổ).
- **Đưa đi đâu:** `storage_charges`.

---

# TASK 9: `storage_charges` (dòng 353-364, bảng đích, không có CTE)

- **Làm gì:** ghép thành bảng cuối, 8 cột, mỗi container một dòng.
- **Trước → Sau:** lấy `visits_latest`, nối `visit_charges` (tiền) và `visit_lines` (bên thanh toán). Đổi `tot_i` và `per_i` từ 1/10,000 đô sang xu bằng số nguyên, làm tròn nửa ra xa số 0, rồi định dạng 2 chữ số thập phân. Container không có tiền coi là 0. **Loại container của hãng test.**
- **Đưa đi đâu:** đây là kết quả cuối.

---

## Ví dụ xuyên suốt, từng bước

| Bước | Giá trị |
|---|---|
| Thô | `' 12345678 '`, `'Gate-Out'`, `days_chg = '1.0'`, giờ `2026-10-01 03:30:00+0530`, mã giá `std1` |
| `unit_visit_history` | `12345678`, `gate_out`, `1.0`, `2026-09-30T22:00:00Z`, `STD1` |
| `visits_latest` | mỗi cột lấy giá trị mới nhất khác NULL; trạng thái thành `gated_out` |
| `visit_days` | (`12345678`, ngày tính phí, `1.0`, `STD1`) |
| `tariff_day_rates` | (`STD1`, ngày đó) có giá, ví dụ `147200` |
| `visit_charges` | `tot_i = 147200` |
| `storage_charges` | `storage_usd = 14.72` |

## 3 điều cần nhớ

1. **Làm sạch một lần, đúng quy tắc chung, ở task 1.** Mọi task sau đọc dữ liệu đã sạch.
2. **"Mới nhất" nghĩa là mới nhất khác NULL cho từng cột**, không phải lấy dòng mới nhất.
3. **Tiền là tổng theo ngày**, mỗi ngày dùng giá của đúng ngày đó, và ngày bị tính lại thì thay thế chứ không cộng thêm.
