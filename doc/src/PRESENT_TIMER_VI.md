# Thuyết trình TIMER — bản đọc

**Người viết:** Nghĩa VT · **Ngày:** 22/09/2026 · **Khớp tài liệu:** `QNSC_TIMER_MAS` **V1.1**

## Dùng file này thế nào

**Phần I là bài nói**, bảy mục, khoảng **5 phút**. **Phần II không đọc lên** — chiều
sâu và câu hỏi thầy hay hỏi. Thuật ngữ, tên tín hiệu, tên thanh ghi giữ tiếng Anh.

## Slide

| Hình | File | Nội dung | Lúc nào |
|---|---|---|---|
| **A** | `img/fig_timer_block.png` | Figure 1 — một `apb_timer_unit`: 2 counter, 2 prescaler, APB regfile | mục 3 tới hết |

---

# PHẦN I — BÀI NÓI

## 1. Mở đầu, một câu

TIMER0 và TIMER1 là **hai instance của `pulp-platform/apb_timer_unit`** — bộ đếm đa
năng. Đây là IP, khối của em là **wrapper**: instantiate, tie-off, map APB. TIMER0
và TIMER1 khác nhau **chỉ ở cách cấu hình**, cùng một IP.

## 2. Bẫy tên phải nói trước

Repo tên là `timer_unit`, nhưng module em dùng là **`apb_timer_unit`**. Và IP này
**khác hẳn** PWM: PWM là `apb_adv_timer`, có channel pin. `apb_timer_unit` **không có
channel pin nào** — chỉ đếm và báo interrupt. Tên dễ nhầm nhất: bốn module *bên trong*
`apb_adv_timer` cũng tên Timer0–Timer3, nên "Timer0" xuất hiện ở hai tầng, hai nghĩa.

## 3. Bên trong một instance

Một `apb_timer_unit` chứa **hai counter 32-bit**, mỗi cái một **prescaler 8-bit**,
một APB register file, và logic interrupt. Không gì khác.

Hai counter đó dùng được **hai kiểu**:
- **hai timer 32-bit độc lập**, hoặc
- **một timer 64-bit** — hai counter nối chuỗi, `counter_hi` tăng đúng một lần mỗi
  lần `counter_lo` tràn (RTL nâng carry tường minh).

## 4. Hai instance cấu hình khác nhau

- **TIMER0 = một timer 64-bit**, là **timebase** của QSOC. Nên nó chỉ báo **1 nguồn
  interrupt** (`irq_lo_o`).
- **TIMER1 = hai timer 32-bit độc lập**, cả hai output đều dùng → **2 nguồn**
  (`irq_lo_o`, `irq_hi_o`).

Tổng: TIMER0 + TIMER1 góp **3 nguồn** interrupt cho INTMAP.

## 5. Vì sao TIMER0 phải là 64-bit

Ở 20 MHz, không prescaler: một counter 32-bit tràn sau **214 giây**, còn 64-bit thì
~29 000 năm. Một timebase mà tràn thì firmware phải **đếm số lần tràn liên tục** —
64-bit bỏ hẳn việc đó. Còn `apb_adv_timer` (PWM) chỉ 16-bit, tràn sau **3,28 ms**,
hợp cho sóng ngắn lặp lại, không hợp làm timebase.

## 6. Dạng interrupt: pulse hay level tùy mode

Đây là chỗ dễ bị hỏi. Cùng một counter:
- **Periodic (compare-and-clear):** mỗi lần chạm target là một **pulse**.
- **One-shot:** giữ **mức** — vì comparator so-bằng và **không bị counter enable
  chặn**, nên khi đã chạm target thì điều kiện match giữ đúng mãi.

Firmware phải biết mình đang ở mode nào để xử interrupt đúng.

## 7. Clock gate: TIMER0 mở, TIMER1 đóng out-of-reset

- **TIMER0 mở** ngay sau reset — nó là timebase, phải chạy trước khi firmware hỏi.
- **TIMER1 đóng** — nó là timeout, chỉ cần khi firmware bật.

Đây là quyết định tích hợp của em, ghi trong MAS mục 5.8.

---

# PHẦN II — KHÔNG ĐỌC LÊN

## Ba module bên trong

| Module | Số | Vai trò |
|---|---|---|
| `apb_timer_unit` | 1/instance | top: 2 counter + 2 prescaler + APB regfile + interrupt |
| `timer_unit_counter` | 2 | counter 32-bit |
| `timer_unit_counter_presc` | 2 | prescaler 8-bit trước mỗi counter |

## Tie-off (quyết định wrapper, không phải IP)

- `ref_clk_i` nối vào clock domain, `REF_CLK_EN` để 0 — prescaler một mình đã tới 15
  giờ, không cần dài hơn.
- `event_lo_i`/`event_hi_i` tie 0 — chưa block nào cần; nối lại chỉ là một dây.

## Ngân hàng câu hỏi

**"TIMER0 và TIMER1 khác gì nhau?"**
Cùng một IP `apb_timer_unit`. Khác **cấu hình**: TIMER0 chạy 64-bit (1 interrupt,
timebase, gate mở); TIMER1 chạy hai 32-bit độc lập (2 interrupt, gate đóng).

**"Sao interrupt lúc pulse lúc level?"**
Periodic thì pulse; one-shot thì level. Vì comparator so-bằng không bị counter enable
chặn — chạm target rồi thì match giữ đúng, thành mức. Đọc từ RTL.

**"Sao không dùng chuẩn RISC-V timer (`mtime`/`mtimecmp`)?"**
QSOC không có CLINT, nên `mip.MTIP` không bao giờ set — timer tick tới như một
peripheral interrupt bình thường. Hệ quả: RTOS port sang chip này phải tự viết timer
driver. Đây là giới hạn được ghi ra, không giấu.

**"Sao TIMER0 phải 64-bit?"**
32-bit tràn sau 214 s ở 20 MHz; timebase mà tràn thì firmware phải đếm wrap liên tục.
64-bit (~29 000 năm) bỏ hẳn việc đó.

**"Đây có phải cùng IP với PWM không?"**
Không. PWM là `apb_adv_timer` (16-bit, có channel pin, 4 event line). TIMER dùng
`apb_timer_unit` (32/64-bit, không channel pin). Chỉ trùng tên module con.

**"Đóng góp của em là gì nếu toàn IP?"**
Wrapper: chọn mode mỗi instance, tie-off `ref_clk`/`event`, map APB, và quyết clock
gate mặc định. Cộng đọc RTL đủ kỹ để biết pulse-vs-level và cách chain 64-bit.

## Bản hai phút

TIMER0/TIMER1 là hai instance `apb_timer_unit` — cùng IP, khác cấu hình. Mỗi instance
có 2 counter 32-bit + prescaler, dùng làm hai timer 32-bit hoặc một 64-bit. **TIMER0
= 64-bit timebase (1 interrupt, gate mở out-of-reset); TIMER1 = hai 32-bit (2
interrupt, gate đóng)** — tổng 3 nguồn cho INTMAP. Interrupt là **pulse khi periodic,
level khi one-shot**. Khác IP với PWM (`apb_adv_timer`, có channel pin). QSOC không
có CLINT nên đây không phải timer chuẩn RISC-V — RTOS phải tự viết driver.
