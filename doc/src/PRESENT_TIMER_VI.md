# Thuyết trình TIMER — bản đọc
**Khớp tài liệu:** `QNSC_TIMER_MAS` V2.1 · **Ngày:** 2026-09-24

## 1. TIMER là gì (2-4 câu)

`TIMER0` và `TIMER1` là hai instance của cùng một IP, `pulp-platform/apb_timer_unit`. Mỗi instance là một APB slave, có hai counter 32-bit, và hai counter này chain được thành một counter 64-bit.
Mỗi counter có prescaler 8-bit, compare bằng đúng (equality), và kéo được một interrupt.
Block không có pad, không có thanh ghi interrupt status. Phần của em là wrapper `m_qnsc_wrap_apb_timer_unit` trong `design/timer`: instantiate, tie-off, và nối vào chip.

## 2. Flow end-to-end

Ví dụ xuyên suốt: `TIMER1` counter `lo` chạy periodic, `TIMER0` làm 64-bit time base.

1. **SCRC mở clock và nhả reset.** Cả hai TIMER nằm trong cluster `peri`. Mỗi instance có clock gate riêng `CLK_EN[TBD]` và reset riêng `o_rst_timer0_n` / `o_rst_timer1_n`.
   - Ra khỏi reset, gate của `TIMER0` **mở**, gate của `TIMER1` **đóng**.
   - Nên trước khi đụng `TIMER1`, firmware phải ghi `CLK_EN` trong `SCRC` để mở gate. Gate còn đóng mà truy cập thì `SCRC` gated-domain responder trả error.
   - Sau reset, mọi thanh ghi TIMER = 0: counter chưa chạy, `MODE_64` = 0, `IRQ_EN` = 0.
2. **Firmware cấu hình qua `P_BUS` (APB).** Ibex đi qua `AXI2APB` xuống `P_BUS`, vào `APB_M7` (`TIMER0`, `0x8001_C000`) hoặc `APB_M8` (`TIMER1`, `0x8002_0000`). `P_BUS` trừ base, TIMER chỉ nhận offset. Chỉ dùng word store.
   - Ghi `TIMER_CMP_LO` = giá trị compare.
   - Ghi `CFG_REG_LO`: `IRQ_EN` = 1, `CMP_CLR` = 1 (periodic), `PRESC_EN` và `PRESC` nếu cần chia chậm. `ONE_SHOT` = 1 nếu muốn one-shot.
   - Ghi bất kỳ giá trị nào vào `TIMER_START_LO` → `CFG_REG_LO.ENABLE` = 1, counter bắt đầu chạy.
   - Phía Ibex: bật bit `mie` tương ứng (22 cho `TIMER1`, 26 cho `TIMER0`) và `mstatus.MIE`.
3. **Counter đếm qua prescaler.** Counter tăng một lần mỗi **tick**.
   - `PRESC_EN` = 0: tick mỗi cycle `HCLK` (20 MHz). `PRESC_EN` = 1: tick mỗi `PRESC`+1 cycle.
   - `REF_CLK_EN` phải để 0: trong QSOC `ref_clk_i` = 0, bật lên là counter đứng yên.
4. **Match kéo interrupt.** Khi count = `TIMER_CMP_LO`, match flag lên 1. `irq_lo_o` = `match_lo & IRQ_EN`, là tổ hợp.
   - Periodic: counter clear về 0, chạy tiếp, interrupt là 1-cycle pulse.
   - One-shot có prescaler: counter dừng ở `CMP`, interrupt là level, giữ tới khi firmware clear. Hành vi one-shot MAS ghi **confirm in simulation**.
5. **INTMAP đưa tới Ibex.** INTMAP chỉ là cổng OR, không có flop.
   - `TIMER0.irq_lo_o` → line 10 → `irq_fast_i[10]` → Ibex trap với `mcause` 26 (vector `mtvec + 0x68`).
   - `TIMER1.irq_lo_o | irq_hi_o` → line 6 → `irq_fast_i[6]` → `mcause` 22 (vector `mtvec + 0x58`).
   - `mcause` = 16 + line, nên core tự biết nguồn, không cần đọc claim register.
   - Lưu ý: Ibex không latch pulse. Pulse rơi đúng lúc `mstatus.MIE` hoặc bit `mie` đang tắt thì mất; periodic thì kỳ sau lại có.
6. **Handler clear.** TIMER không có status register, không có acknowledge riêng.
   - Pulse: tự hết sau 1 cycle, không cần clear.
   - Level one-shot: phải clear **trước `mret`**, nếu không handler bị gọi lại. Cách clear: ghi `TIMER_RESET_x`, hoặc `CFG_REG_x.RESET` = 1, hoặc ghi `TIMER_CMP_x` / `TIMER_VAL_x` sao cho count khác compare, hoặc `IRQ_EN` = 0.
   - **Mơ hồ `TIMER1` lo/hi:** hai nguồn OR chung line 6, không register nào ghi ai kéo. One-shot thì đoán được: counter đã start mà đọc `ENABLE` = 0 là counter đã match. Periodic và free-running thì **không có cách nào** phân biệt.
7. **Sau đó.**
   - Periodic (`CMP_CLR` = 1): counter đã về 0, tự đếm tiếp, kỳ sau lại pulse. Không cần firmware làm gì.
   - One-shot: `ENABLE` đã bị clear, counter dừng. Ghi `TIMER_START_x` một mình **không** chạy lại counter đang đứng ở match, vì điều kiện one-shot lại clear `ENABLE`. Phải clear match trước (ví dụ `TIMER_RESET_x`), rồi mới start.

**TIMER0 = 64-bit time base.** Firmware ghi `CFG_REG_LO.MODE_64` = 1. Counter `hi` chỉ tăng ở tick mà `TIMER_VAL_LO` = `0xFFFF_FFFF`, nên `{TIMER_VAL_HI, TIMER_VAL_LO}` là một count 64-bit.
- `CFG_REG_LO` điều khiển tất cả; `CFG_REG_HI` giữ = 0 (nếu không, lúc `CFG_REG_LO.ENABLE` = 0 mà `CFG_REG_HI.ENABLE` = 1 thì counter `hi` chạy một mình).
- Match khi cả hai nửa bằng `TIMER_CMP_HI`/`TIMER_CMP_LO`. Chỉ có `irq_lo_o`; `irq_hi_o` = 0 và để hở.
- Để làm tick, firmware đọc count mới, cộng khoảng cần chờ, ghi compare. Compare đã bị count vượt qua thì chỉ match sau khi wrap, 2^64 tick, tức là không bao giờ.
- Why 64-bit: 32-bit ở 20 MHz wrap sau 214.7 s. Time base mà wrap thì firmware phải đếm số lần wrap.

**TIMER1 = hai timer 32-bit.** `MODE_64` = 0, counter `lo` và `hi` độc lập, mỗi cái một `CFG`, một `CMP`, một interrupt. Hai interrupt OR chung line 6.

| IP liên quan | TIMER cần gì từ IP đó |
|---|---|
| `SCRC` | clock gate `CLK_EN` (`TIMER0` mở, `TIMER1` đóng lúc reset), reset `o_rst_timer0_n` / `o_rst_timer1_n`, error responder khi gate đóng; vị trí bit `CLK_EN` và `SOFT_RST_CTRL` còn TBD |
| `P_BUS` (APB) | port `APB_M7` / `APB_M8`, vùng 16 KiB mỗi instance, `PADDR[11:0]` = offset trong vùng |
| `INTMAP` | line 10 cho `TIMER0.irq_lo_o`; line 6 = OR của `TIMER1.irq_lo_o` và `irq_hi_o` |
| Ibex | `irq_fast_i[10]` / `[6]`, bit `mie` 26 / 22, `mstatus.MIE`, handler clear level trước `mret` |

## 3. Giải thích từng hình

### Figure 3-1. TIMER0 and TIMER1 in QSOC

Hình này trả lời: hai TIMER nằm đâu trong chip, lấy clock, reset, bus từ đâu, và interrupt đi về đâu.

| Block | Là gì | Nối với ai / tín hiệu |
|---|---|---|
| `P_BUS (APB4, 20 MHz)` | bus APB của peripheral | `APB_M7` → `TIMER0`, `APB_M8` → `TIMER1` |
| `SCRC clock gate CLK_EN[TBD]` (trái) | clock gate của `TIMER0`, mở lúc reset | `HCLK` → `TIMER0` |
| `SCRC o_rst_timer0_n` | reset của `TIMER0` | `HRESETn` → `TIMER0` |
| `TIMER0` | `apb_timer_unit` ở `0x8001_C000`, `MODE_64` = 1 | ra `irq_lo_o`, `irq_hi_o`, `busy_o` |
| `event_lo_i = 0 / event_hi_i = 0 / ref_clk_i = 0` | tie-off | vào `TIMER0` (và tương tự `TIMER1`) |
| `n.c.` dưới `irq_hi_o` | để hở | `TIMER0.irq_hi_o`, luôn 0 ở 64-bit mode |
| `n.c.` dưới `busy_o` | để hở | `busy_o` của mỗi TIMER, không ai dùng |
| `SCRC clock gate CLK_EN[TBD]` (phải) | clock gate của `TIMER1`, đóng lúc reset | `HCLK` → `TIMER1` |
| `SCRC o_rst_timer1_n` | reset của `TIMER1` | `HRESETn` → `TIMER1` |
| `TIMER1` | `apb_timer_unit` ở `0x8002_0000`, `MODE_64` = 0 | ra `irq_lo_o`, `irq_hi_o` vào OR |
| `INTMAP` (khung nét đứt) | khối gom interrupt, chỉ có dây và OR | nhận interrupt, ra `irq_fast_i` |
| `OR` | cổng OR của `TIMER1` | `irq_lo_o`, `irq_hi_o` → `irq_fast_i[6]` |
| `irq_fast_i[10] mcause 26` | input fast interrupt của Ibex | từ `TIMER0.irq_lo_o` |
| `irq_fast_i[6] mcause 22` | input fast interrupt của Ibex | từ OR của `TIMER1` |

Cách đọc:
1. Đọc từ trên xuống: `P_BUS` là đường firmware ghi và đọc thanh ghi.
2. Bên trái mỗi TIMER: `SCRC` cấp `HCLK` qua clock gate và `HRESETn`. Chữ "open/closed at reset" là khác biệt tích hợp giữa hai instance.
3. Bên dưới: mũi tên đi lên là tie-off hằng 0; mũi tên đi xuống là output.
4. `TIMER0` chỉ có `irq_lo_o` đi tiếp, thẳng vào `irq_fast_i[10]`.
5. `TIMER1` có hai dây đi vào `OR`, rồi một dây vào `irq_fast_i[6]`.

**Hỏi:** Sao dùng hai instance mà không dùng một block hai timer?
**Đáp:** `QSOC_HAS` cấp hai APB port và hai bit clock gate. Vậy hai timer tắt được độc lập.

**Hỏi:** Sao `TIMER0` mở gate lúc reset, còn `TIMER1` đóng?
**Đáp:** `TIMER0` là time base, phải chạy được mà firmware không cần ghi `SCRC` trước. `TIMER1` dùng cho timeout, chỉ cần khi firmware bật.

**Hỏi:** `MODE_64 = 1` trong hình là tham số phần cứng à?
**Đáp:** Không. Hai instance có parameter giống hệt. `MODE_64` là bit firmware ghi, reset = 0.

**Hỏi:** Hai interrupt của `TIMER1` OR chung thì mất gì?
**Đáp:** Mất khả năng biết nguồn. Không có status register, nên ở periodic firmware không phân biệt được `lo` hay `hi`.

### Figure 3-2. Inside one TIMER instance

Hình này trả lời: bên trong một `apb_timer_unit` có gì, và từ tick tới interrupt đi qua những khối nào.

| Block | Là gì | Nối với ai / tín hiệu |
|---|---|---|
| `ref_clk_i` | input clock tham chiếu, trong QSOC = 0 | vào khối sync |
| `ref_clk_i sync + edge 4 flops` | đồng bộ và bắt cạnh lên của `ref_clk_i` | `ref edge` → prescaler lo và hi |
| `prescaler lo` | chia `/(PRESC+1)`, bypass khi `PRESC_EN` = 0 | nhận `CFG`, ra `tick` → `counter_lo` |
| `prescaler hi` | như trên, cho counter `hi` | ra `tick` → `counter_hi` |
| `event_lo_i / event_hi_i` | input start bằng phần cứng, tie 0 | vào register file (set `ENABLE` khi `IEM` = 1) |
| `APB register file` | `CFG_REG`, `TIMER_VAL`, `TIMER_CMP`, `TIMER_START`, `TIMER_RESET` | `CFG` → prescaler, `CMP` → counter, APB hai chiều |
| `busy_o` | output trạng thái, để hở | từ register file |
| `APB PADDR[5:0]` | cổng bus, chỉ decode 6 bit | hai chiều với register file |
| `counter_lo 32-bit == TIMER_CMP_LO` | counter và compare của `lo` | ra `match_lo`, và `MODE_64 carry` → `counter_hi` |
| `counter_hi 32-bit == TIMER_CMP_HI` | counter và compare của `hi` | ra `match_hi` |
| `IRQ logic` | AND match với `IRQ_EN`, chọn theo `MODE_64` | ra `irq_lo_o`, `irq_hi_o` |
| `irq_lo_o`, `irq_hi_o` | hai output interrupt | ra `o_int_timer[0]`, `[1]` của wrapper |

Cách đọc (trái sang phải):
1. Nguồn tick: `HCLK`, hoặc cạnh `ref_clk_i` (luôn 0 trong QSOC).
2. Prescaler: bypass nếu `PRESC_EN` = 0, không thì ra một `tick` mỗi `PRESC`+1 lần.
3. Counter: tăng mỗi `tick`, so bằng với `TIMER_CMP`. Match flag là flop: lên 1 ở cycle **ngay sau** mỗi cycle count = `CMP`, **kể cả khi `ENABLE` = 0**.
4. `MODE_64 carry`: ở 64-bit mode, `counter_hi` chỉ tăng khi `counter_lo` = `0xFFFF_FFFF`.
5. `IRQ logic`: 32-bit thì mỗi match ra một irq; 64-bit thì `irq_lo_o` = `match_lo & match_hi & IRQ_EN`, `irq_hi_o` = 0.
6. Register file ở giữa: firmware ghi `CFG` và `CMP` xuống, và đọc lại count.

**Hỏi:** Sao one-shot có prescaler lại thành level?
**Đáp:** Match flag không bị `ENABLE` chặn. Counter dừng ở `CMP` thì count vẫn bằng compare, flag giữ 1 mãi tới khi firmware clear. MAS ghi confirm in simulation.

**Hỏi:** 64-bit chain làm sao cho đúng?
**Đáp:** Theo đường `MODE_64 carry`: `hi` tăng đúng ở tick mà `lo` = `0xFFFF_FFFF`, có hay không có prescaler.

**Hỏi:** Khối `ref_clk_i` có tác dụng gì trong QSOC?
**Đáp:** Không. IP có sẵn, nhưng QSOC không có reference clock nên tie 0. `REF_CLK_EN` = 1 thì counter dừng.

**Hỏi:** Chỉ decode `PADDR[5:0]` thì sao?
**Đáp:** Map 64 byte lặp lại 256 lần trong vùng 16 KiB. `base + 0x40` chính là `CFG_REG_LO`.

## 4. Giải thích từng bảng

### Revision history (không đánh số)

Bảng ghi phiên bản. V2.0 viết lại thành spec thuần; V2.1 sửa hành vi one-shot và `CFG_REG_HI[31]` theo RTL, thêm interface, register map đầy đủ, tie-off và hai hình. Lý do nằm trong `QNSC_TIMER_DECISIONS.md`.

### Table 1-1. Instance assignment

Để làm gì: tóm tắt hai instance khác nhau ở đâu.
- Cột: `Instance`; `Base` là địa chỉ; `APB port` trên `P_BUS`; `Mode` là firmware ghi `MODE_64`; `Clock gate out of reset` là trạng thái gate sau reset; `Interrupt` là dây nào vào line nào của Ibex.
- Dòng cần chỉ: `TIMER0` 64-bit, gate open, chỉ `irq_lo_o` → `irq_fast_i[10]` (mcause 26). `TIMER1` hai 32-bit, gate closed, cả hai irq → `irq_fast_i[6]` (mcause 22).

**Hỏi:** Hai instance có khác RTL không?
**Đáp:** Không. Cùng wrapper, cùng parameter. Chỉ khác `MODE_64` do firmware ghi, reset state của gate, và line INTMAP.

### Table 4-1. Upstream IP used

Để làm gì: nói rõ lấy IP nào, ở commit nào, licence gì.
- Cột: `From` là repo; `Module` là ba module dùng; `Commit` là `4c69615c`; `Licence` là SolderPad 0.51.
- Chỉ vào: `apb_timer_unit` là top, `timer_unit_counter` là counter, `timer_unit_counter_presc` là prescaler.

**Hỏi:** Repo tên `timer_unit` mà module là `apb_timer_unit`?
**Đáp:** Đúng, tên repo không phải tên module. Module top là `apb_timer_unit`.

### Table 5-1. TIMER interface

Để làm gì: danh sách port của wrapper, và mỗi port nối vào port nào của IP.
- Cột: `Signal` theo naming rule; `Dir`; `Width`; `Description` ghi port IP tương ứng.
- Dòng cần chỉ: `i_clk_peri` → `HCLK`; `i_rst_n_peri` → `HRESETn`, async active-low; `i_bus_apb_paddr` 12 bit nhưng chỉ decode `[5:0]`; `i_bus_apb_pstrb`, `i_bus_apb_pprot` không nối; `o_bus_apb_pready` = `PSEL & PENABLE`; `o_bus_apb_pslverr` hằng 0; `o_int_timer[1:0]` = {`irq_hi_o`, `irq_lo_o`}.

**Hỏi:** `PSTRB` không nối thì byte store ra sao?
**Đáp:** Ghi cả 32 bit của `PWDATA`. Nên firmware chỉ dùng word store.

**Hỏi:** Có wait state không?
**Đáp:** Không. `PREADY` = `PSEL & PENABLE`, mọi truy cập xong trong zero wait state.

### Table 6-1. Register map

Để làm gì: mọi thanh ghi, field, bit, access và reset của một instance. Tất cả reset = 0.
- Cột: `Offset`; `Register`; `Field`; `Bits`; `Access` (RW, WO, RSVD); `Reset`; `Description`.
- `CFG_REG_LO` (`0x00`): `ENABLE`, `RESET` (tự về 0 cycle sau), `IRQ_EN`, `IEM` (vô tác dụng vì event tie 0), `CMP_CLR`, `ONE_SHOT`, `PRESC_EN`, `REF_CLK_EN` (bật là dừng), `PRESC` [15:8], bit 30:16 lưu nhưng không làm gì, `MODE_64` bit 31.
- `CFG_REG_HI` (`0x04`): bit 15:0 giống `CFG_REG_LO`; bit 31 **phải = 0**.
- `TIMER_VAL` (`0x08`/`0x0C`): đọc count, ghi để load. `TIMER_CMP` (`0x10`/`0x14`): giá trị compare.
- `TIMER_START` (`0x18`/`0x1C`) và `TIMER_RESET` (`0x20`/`0x24`): WO, ghi gì cũng được, đọc ra 0.
- `0x28`-`0x3C`: RSVD, ghi bị bỏ, đọc ra 0.

**Hỏi:** Sao `CFG_REG_HI[31]` phải = 0?
**Đáp:** Nó không bị bỏ qua. Ở 32-bit mode, bit này = 1 làm counter `hi` không tự clear `ENABLE` khi match ở one-shot.

**Hỏi:** Ở 64-bit mode `CFG_REG_HI` làm gì?
**Đáp:** Khi `CFG_REG_LO.ENABLE` = 1, chỉ `RESET` của `CFG_REG_HI` có tác dụng. Firmware giữ `CFG_REG_HI` = 0.

### Table 7-1. Tick source

Để làm gì: counter tăng theo cái gì, và 32-bit wrap sau bao lâu ở 20 MHz.
- Cột: `REF_CLK_EN`, `PRESC_EN` chọn nguồn; `Tick` là khi nào counter tăng; `32-bit wrap at 20 MHz` là thời gian đầy vòng.
- Dòng 1: không prescaler, tick mỗi `HCLK`, wrap 214.7 s.
- Dòng 2: prescaler, tick mỗi `PRESC`+1 cycle, wrap tối đa 15.3 h (`PRESC` = 255).
- Dòng 3: `REF_CLK_EN` = 1, "never", vì `ref_clk_i` = 0 nên không có tick.

**Hỏi:** "Counter advances every cycle" nghĩa chính xác là gì?
**Đáp:** `REF_CLK_EN` = 0 và (`PRESC_EN` = 0 hoặc `PRESC` = 0).

### Table 7-2. Interrupt equations

Để làm gì: công thức tổ hợp của hai output interrupt.
- Cột: `Mode`; `irq_lo_o`; `irq_hi_o`.
- 32-bit: mỗi output = match của counter đó AND `IRQ_EN` của nó.
- 64-bit: `irq_lo_o` = `match_lo & match_hi & CFG_REG_LO.IRQ_EN`; `irq_hi_o` = 0.

**Hỏi:** Interrupt có flop không?
**Đáp:** Match flag là flop. Interrupt thì tổ hợp từ flag và `IRQ_EN`, nên `IRQ_EN` = 0 là hạ interrupt ngay.

### Table 7-3. Interrupt shape by mode

Để làm gì: với từng tổ hợp `CMP_CLR`/`ONE_SHOT` và tốc độ tick, counter làm gì lúc match và interrupt là pulse hay level.
- Cột: `CMP_CLR`, `ONE_SHOT` là bit cấu hình; `Counter advances` là mỗi cycle hay prescaled; `At the match` là counter làm gì; `Interrupt` là hình dạng.
- **Dòng 1, 1/0, periodic:** counter đếm 0..`CMP`, match thì clear về 0 và chạy tiếp. Clear đến ngay sau match flag, nên luôn là **1-cycle pulse**, kể cả prescaled.
- **Dòng 2, 0/0, mỗi cycle, free-running:** counter chạy qua `CMP` sang `CMP`+1 ở cycle sau. Flag chỉ lên 1 cycle → **1-cycle pulse**. Lần match sau là sau wrap.
- **Dòng 3, 0/0, prescaled, free-running:** counter đứng ở `CMP` trọn một tick (`PRESC`+1 cycle) rồi mới tăng. Flag giữ suốt tick đó → **pulse dài một tick**.
- **Dòng 4, 0/1, mỗi cycle, one-shot:** `ENABLE` bị clear, nhưng `ENABLE` đã register vẫn = 1 thêm một cycle. Counter nhích lên `CMP`+1 rồi dừng ở đó → count khác compare → **1-cycle pulse**.
- **Dòng 5, 0/1, prescaled, one-shot:** `ENABLE` bị clear, cycle đó không có tick, counter dừng đúng ở `CMP`. Flag giữ 1 → **level**, giữ tới khi firmware clear (7.5).
- **Dòng 6, 1/1:** counter clear về 0 và dừng. Count khác compare → **1-cycle pulse**.
- Tóm lại: periodic luôn là pulse; one-shot là level chỉ khi prescaled, là pulse khi đếm mỗi cycle. Hai dòng one-shot (4, 5) MAS ghi **confirm in simulation**.

**Hỏi:** Sao cùng one-shot mà lúc pulse lúc level?
**Đáp:** Còn tùy cycle ngay sau match có tick hay không. Có tick thì counter nhích qua `CMP` và flag rơi; không có tick thì counter đứng ở `CMP` và flag giữ.

**Hỏi:** Pulse chỉ 1 cycle, có bị mất không?
**Đáp:** Có thể. Ibex và INTMAP không latch; pulse rơi lúc `mstatus.MIE` hoặc bit `mie` tắt, hoặc trong Debug Mode, thì không có trap. Periodic thì kỳ sau lại có.

### Table 7-4. Interrupt period, CMP >= 1

Để làm gì: khoảng cách giữa hai interrupt, với `CMP` >= 1.
- Cột: `Mode`; `Period` tính bằng cycle `HCLK` hoặc tick.
- Periodic đếm mỗi cycle: `CMP`+1 cycle, vì counter đi qua `CMP`+1 giá trị 0..`CMP`.
- Periodic prescaled (`PRESC` >= 1): `CMP` x (`PRESC`+1) cycle. Không phải (`CMP`+1) x (`PRESC`+1), vì clear đến ngay sau match chứ không đợi hết tick.
- Free-running: 2^32 tick, hoặc 2^64 tick ở 64-bit mode.
- Hai công thức periodic MAS ghi **confirm in simulation**.

**Hỏi:** Muốn interrupt mỗi 1 ms, không prescaler?
**Đáp:** 1 ms = 20 000 cycle, nên `CMP` = 19 999, `CMP_CLR` = 1.

### Table 9-1. Functions this block does not provide

Để làm gì: nói thẳng block không có gì, và ai lo thay.
- Cột: `Function`; `Where it lives`.
- Dòng cần chỉ: interrupt status = **nowhere**; acknowledge = firmware ghi vào block (7.5); nguồn của `irq_fast_i[6]` = nowhere ở periodic; error response = `SCRC` responder, chỉ khi gate đóng; compare >= = nowhere; `mtime`/`mtimecmp` = nowhere, `irq_timer_i` tie 0 ở core; gom lên line CPU = `INTMAP`.

**Hỏi:** Sao không phải timer chuẩn RISC-V?
**Đáp:** QSOC không có `mtime`/`mtimecmp`, `irq_timer_i` tie 0. Tick của TIMER đến như một fast interrupt bình thường.

**Hỏi:** Không có compare >= thì rủi ro gì?
**Đáp:** Compare đã bị count vượt thì chỉ match sau wrap: 214.7 s ở 32-bit, 2^64 tick ở 64-bit. Firmware phải tính compare từ count vừa đọc, có margin cho latency.

### Table 10-1. Tie-offs

Để làm gì: các port IP bị buộc hằng hoặc để hở trong QSOC, và lý do.
- Cột: `Port`; `Tied to`; `Why`.
- `event_lo_i`, `event_hi_i` = 0: không có nguồn start phần cứng, `IEM` vô tác dụng.
- `ref_clk_i` = 0: không có reference clock; `REF_CLK_EN` = 1 làm counter dừng.
- `busy_o` hở: không ai dùng. `TIMER0.irq_hi_o` hở ở `INTMAP`: luôn 0 ở 64-bit mode.
- `i_bus_apb_pstrb`, `i_bus_apb_pprot` hở: IP không có input này.

**Hỏi:** Sao tie `ref_clk_i` = 0 mà không nối clock?
**Đáp:** Với `REF_CLK_EN` = 0 thì hành vi giống hệt. Hằng số giữ clock net khỏi chân data của flop.

### Table 11-1. Requirements on other owners

Để làm gì: những gì TIMER cần người khác làm, và nếu thiếu thì chặn cái gì.
- Cột: `Item`; `Owner`; `What it blocks`.
- Bus owner: `i_bus_apb_paddr[11:0]` là 12 bit thấp của offset trong vùng (P_BUS đã trừ base; bit 13:12 không dùng).
- `SCRC` owner: vị trí bit `CLK_EN` và `SOFT_RST_CTRL`, còn TBD, chặn việc nối clock và reset của wrapper.
- `SCRC` owner: reset value của gate, `TIMER0` mở, `TIMER1` đóng; thiếu thì `TIMER0` không chạy được trước khi firmware ghi `SCRC`.
- Dưới bảng là 7 luật firmware: tính compare từ count mới; clear level trước `mret`; `CFG_REG_HI[31]` = 0 và chỉ word store; không đóng gate khi interrupt đang lên; đóng gate `TIMER0` là time base dừng mà không để lại dấu; đọc count 64-bit theo thứ tự `HI`, `LO`, `HI` (hai `HI` khác nhau thì đọc lại, vì `LO` có thể wrap giữa hai lần đọc); restart one-shot bằng `TIMER_RESET_x` rồi `TIMER_START_x`.

**Hỏi:** Sao không được đóng gate khi interrupt đang lên?
**Đáp:** Gate đóng thì flag giữ nguyên, level giữ nguyên. Mà block lại không ghi được để clear, nên handler bị gọi lại mãi.

### Table A-1. Acronyms

Giải nghĩa viết tắt: APB, `mtime`/`mtimecmp` (thanh ghi machine timer của RISC-V), SCRC (bộ điều khiển clock và reset).

### Table B-1. First review

Ghi nhận xét lần review đầu của thầy (2026-09-23): tài liệu quá dài, trùng lặp gây sai thông tin. Trả lời: V2.0 viết lại, V2.1 chuyển hết phần lý do sang `_DECISIONS`.
