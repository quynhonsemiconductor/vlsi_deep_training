# Thuyết trình PWM — bản đọc

**Người viết:** Nghĩa VT · **Ngày:** 22/09/2026 · **Khớp tài liệu:** `QNSC_PWM_MAS` **V1.5**
(xem lưu ý ở cuối về một chỗ MAS cần sửa cho khớp RTL)

## Dùng file này thế nào

**Phần I là bài nói**, bảy mục, khoảng **5 phút**. **Phần II không đọc lên** — chiều
sâu và câu hỏi thầy hay hỏi. Thuật ngữ, tên tín hiệu giữ tiếng Anh.

## Slide

| Hình | File | Nội dung | Lúc nào |
|---|---|---|---|
| **A** | `img/fig_pwm_block.png` | Figure 1 — `apb_adv_timer`: 4 module, channel outputs, event lines | mục 3 tới hết |

---

# PHẦN I — BÀI NÓI

## 1. Mở đầu, một câu

PWM là **một instance `pulp-platform/apb_adv_timer`**. Khối của em là **wrapper**:
instantiate, tie-off, map APB. `TIMER_NBITS = 16`, `EXTSIG_NUM = 32`.

## 2. Bẫy tên phải nói trước

PWM **khác IP với TIMER0/TIMER1**. TIMER dùng `apb_timer_unit` (không channel pin);
PWM dùng `apb_adv_timer` (có channel pin). Bẫy tên: bốn module *bên trong*
`apb_adv_timer` cũng tên Timer0–Timer3 — trùng tên với hai khối TIMER nhưng khác hẳn.

## 3. Cấu trúc: 4 module × 4 channel = 16 output

Một `apb_adv_timer` chứa **bốn module 16-bit độc lập**, mỗi module **bốn comparator**
→ mỗi module có 4 channel output (`pwm_o[3:0]`). Tổng **16 channel output**.

Trong RTL, các channel gom **theo module**:
- `ch_0_o[3:0]` = 4 channel của **module 0** (`u_tim0.pwm_o → ch_0_o`)
- `ch_1_o[3:0]` = 4 channel của **module 1**, và tương tự `ch_2_o`, `ch_3_o`.

Nói cách khác: **`ch_i_o[j]` = channel j của module i**. `ch_0_o` KHÔNG phải "channel
0 của mọi module".

## 4. Tám channel ra pad: PWM_0–PWM_7

QSOC đưa ra pad **4 channel của module 0 (`ch_0_o`) và 4 channel của module 1
(`ch_1_o`)** → PWM_0–PWM_7. Vì mỗi module có prescaler và count-window riêng, **hai
module ra pad → hai tần số nền độc lập**, mỗi tần số 4 channel (duty/phase riêng).
Channel của module 2, 3 không ra pad.

## 5. Bốn event line tới INTMAP

`events_o[3:0]`, mỗi line **một pulse một chu kỳ**. Mỗi line có selector 4-bit chọn
**1 trong 16 channel** (`{ch_3_o,ch_2_o,ch_1_o,ch_0_o}`), một enable, và edge-detect:
`events_o[i] = en[i] & sync[1] & ~sync[0]`. **Im cho tới khi firmware ghi `EVENT_CFG`**
(reset về 0).

## 6. Clock gate đóng → output giữ mức (không an toàn)

`out_filter.sv` chỉ cập nhật output khi `ctrl_active_i` cao. Nên **dừng hoặc gate một
channel → nó giữ nguyên mức cuối**, không tự về mức an toàn. Với power stage, mức giữ
**không phải trạng thái trung tính**. MAS mục 5.9 quy định quy trình firmware kết
thúc bằng **"không bao giờ gate một block đang chạy"**.

## 7. Điểm tích hợp

- `ext_sig_i[3:0]` ← 4 pad `TIM_EXT0–TIM_EXT3` theo thứ tự pad, 28 bit trên tie 0.
  (Quyết định wrapper, không phải property IP.)
- `status_o` mỗi module tồn tại nhưng **không đọc được qua software** — nối lên top
  rồi bỏ trống. Nếu spec cần thấy thì wrapper phải phơi ra.

---

# PHẦN II — KHÔNG ĐỌC LÊN

## Sub-module

`timer_module`, `up_down_counter`, `comparator`, `prescaler`, `lut_4x4`,
`out_filter`, `input_stage`, `timer_cntrl`, `adv_timer_apb_if`.

## Ngân hàng câu hỏi

**"16 channel mà chỉ 8 ra pad, 8 kia đâu?"**
Module 0 và 1 ra pad (8 channel); module 2, 3 không routed ra pad — dùng nội bộ hoặc
làm nguồn event. Có thể route thêm nếu cần, là sửa wrapper.

**"Tại sao 2 tần số mà không phải 4?"**
Vì 8 pad = **2 module** (module 0 + module 1), mỗi module một prescaler/count-window →
2 tần số nền. Bốn channel trong một module chia sẻ base, khác nhau ở duty/phase. Nếu
muốn 4 tần số thì phải đưa ra pad channel của cả 4 module.

**"Event line hoạt động sao?"**
4 line, mỗi line chọn 1 trong 16 channel, edge-detect thành pulse 1 chu kỳ. Chưa ghi
`EVENT_CFG` thì im. Bốn line này chính là 4 nguồn interrupt PWM góp cho INTMAP.

**"Gate clock lúc đang chạy thì sao?"**
Output **giữ mức cuối**, không về 0. Nguy hiểm cho power stage. Nên quy tắc: không
gate block đang chạy; muốn tắt thì dừng đúng trình tự trước.

**"Khác gì TIMER0/1?"**
Khác IP hoàn toàn. `apb_adv_timer`: 16-bit, có channel pin, 4 event line, 4 external
trigger. `apb_timer_unit` (TIMER): 32/64-bit, không channel pin. Chỉ trùng tên module con.

**"Đóng góp của em?"**
Wrapper: port map, tie-off `ext_sig`, chọn pad channel, và đọc RTL đủ kỹ để biết
event là 4-of-16 mux, status_o không đọc được, và gate giữ mức.

## Bản hai phút

PWM là một `apb_adv_timer`: **4 module 16-bit độc lập, mỗi module 4 channel → 16
channel output**, gom theo module (`ch_i_o` = 4 channel của module i). **8 channel ra
pad = module 0 + module 1 → 2 tần số nền độc lập.** 4 event line tới INTMAP, mỗi cái
pulse 1 chu kỳ chọn 1/16 channel, im tới khi set `EVENT_CFG`. Gate clock → output giữ
mức (không an toàn cho power stage). Khác IP với TIMER (`apb_timer_unit`).

---

## LƯU Ý — một chỗ MAS cần sửa cho khớp RTL

`QNSC_PWM_MAS` V1.3 ghi *"`ch_0_o` và `ch_1_o` của **mỗi** module, cho **bốn** tần số
độc lập"*. Đọc RTL (`apb_adv_timer.sv`: `u_tim0.pwm_o → ch_0_o`, …) thì **`ch_0_o` là
4 channel của module 0**, nên 8 pad = **2 module → 2 tần số**, không phải 4. Đây là
điểm nên sửa lại trong MAS (và HAS đã dùng bản đúng: 2 tần số).
