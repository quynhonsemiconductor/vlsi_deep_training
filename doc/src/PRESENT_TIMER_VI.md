# Thuyết trình TIMER — bản đọc
**Khớp tài liệu:** `QNSC_TIMER_MAS` V2.1 · **Ngày:** 2026-09-24

## 1. TIMER là gì (2-4 câu)

`TIMER0` và `TIMER1` là hai instance của cùng một IP, `pulp-platform/apb_timer_unit`. Mỗi instance là một APB slave, có hai counter 32-bit, và hai counter này chain được thành một counter 64-bit.
Mỗi counter có prescaler 8-bit, compare bằng đúng (equality), và kéo được một interrupt.
Block không có pad, không có thanh ghi interrupt status. Phần của em là wrapper `m_qnsc_wrap_apb_timer_unit` trong `design/timer`: instantiate, tie-off, và nối vào chip.

## 2. Flow end-to-end

### Câu chuyện chính: `TIMER1` counter `lo` làm periodic tick

Ví dụ: tick 1 ms, không prescaler. 1 ms ở 20 MHz là 20 000 cycle, periodic đếm mỗi cycle có chu kỳ `CMP`+1, nên `CMP` = 19 999 (Table 7-4).

**Bước 1 — Power-on, SCRC reset TIMER1.** *Ở đâu:* `SCRC`. *Làm gì:* giữ rồi nhả reset `o_rst_timer1_n`. *Đi tiếp:* `o_rst_timer1_n` → `i_rst_n_peri` của wrapper → `HRESETn` của `apb_timer_unit`; mọi thanh ghi TIMER1 về 0, nên `ENABLE` = 0, `IRQ_EN` = 0, `MODE_64` = 0. *Phụ thuộc:* reset là asynchronous active-low; vị trí bit `SOFT_RST_CTRL` còn TBD (Table 11-1). Gate của TIMER1 đóng sau reset, nên lúc này chưa có `HCLK`. *(Vì sao: Mỗi instance có reset và clock gate riêng, nên firmware dừng được TIMER1 mà không dừng time base TIMER0. Đó cũng là lý do dùng hai instance `apb_timer_unit` chứ không phải một block: hệ thống cấp hai APB port và hai gate riêng.)*

**Bước 2 — Firmware mở clock cho TIMER1.** *Ở đâu:* firmware trên Ibex, qua `P_BUS` tới `SCRC`. *Làm gì:* ghi bit `CLK_EN` của TIMER1 (vị trí còn TBD). *Đi tiếp:* clock gate TIMER1 mở, `HCLK` vào `apb_timer_unit` qua `i_clk_peri`. *Phụ thuộc:* TIMER1 đóng gate sau reset (Table 1-1); khi gate đóng, `SCRC` gated-domain responder trả error cho mọi truy cập APB tới vùng TIMER1. *(Vì sao: TIMER1 không làm gì cho tới khi `CMP` và `CFG` được ghi, nên để gate đóng sau reset thì chưa dùng là chưa tốn gì.)*

**Bước 3 — Firmware ghi compare.** *Ở đâu:* firmware trên Ibex, qua `P_BUS`, cổng `APB_M8`, tới TIMER1 (base `0x8002_0000`). *Làm gì:* word store 19 999 vào `TIMER_CMP_LO` (offset `0x10`). *Đi tiếp:* `P_BUS` trừ base, `i_bus_apb_paddr` mang offset, IP decode `PADDR[5:0]`, giá trị vào `TIMER_CMP_LO` của APB register file, rồi xuống bộ compare của `counter_lo`. *Phụ thuộc:* gate đã mở (bước 2); chỉ dùng word store vì `PSTRB` không nối; zero wait state, `PSLVERR` = 0. *(Vì sao: Wrapper không nối `PSTRB`, nên byte hay halfword store vẫn ghi cả 32 bit của `PWDATA` và đè mất các byte khác. Chỉ decode `PADDR[5:0]` thì map lặp lại trong vùng 16 KiB; tài liệu chấp nhận aliasing này, vì thu hẹp decode tốn logic mà chỉ đổi lấy một lỗi firmware không thấy được (`PSLVERR` luôn 0).)*

**Bước 4 — Firmware ghi cấu hình.** *Ở đâu:* firmware, qua `APB_M8`, tới `CFG_REG_LO` (offset `0x00`). *Làm gì:* ghi `IRQ_EN` = 1, `CMP_CLR` = 1, `ONE_SHOT` = 0, `PRESC_EN` = 0, `REF_CLK_EN` = 0, `MODE_64` = 0, `ENABLE` để 0. *Đi tiếp:* `CFG` xuống `prescaler lo` (bypass), `CMP_CLR` tới `counter_lo`, `IRQ_EN` tới `IRQ logic`. *Phụ thuộc:* `REF_CLK_EN` phải = 0, vì `ref_clk_i` tie 0 và bật lên là counter dừng; `MODE_64` giữ 0 với TIMER1; `CFG_REG_HI[31]` giữ 0. *(Vì sao: `ref_clk_i` tie 0 vì chỉ riêng prescaler đã đếm được tới 15.3 h, trong QSOC không có gì đo lâu hơn. Với `REF_CLK_EN` = 0 thì hành vi y hệt, mà tie hằng số thì không kéo clock net vào chân data của flop.)*

**Bước 5 — Firmware bật interrupt ở Ibex.** *Ở đâu:* CSR của Ibex. *Làm gì:* set bit `mie` 22 và `mstatus.MIE`. *Đi tiếp:* từ giờ `irq_fast_i[6]` lên là Ibex trap được. *Phụ thuộc:* handler cho `mcause` 22 phải cài sẵn. *(Vì sao: QSOC không có `mtime`/`mtimecmp`, `irq_timer_i` tie 0, nên tick đi đường fast interrupt như một peripheral thường. Điều đó hợp lệ vì machine timer là tiện ích của platform chứ không bắt buộc ở core; cái giá là tính portable của RTOS, và không có RTOS nào trong scope.)*

**Bước 6 — Firmware start counter.** *Ở đâu:* firmware, qua `APB_M8`, tới `TIMER_START_LO` (offset `0x18`). *Làm gì:* ghi một giá trị bất kỳ. *Đi tiếp:* `CFG_REG_LO.ENABLE` = 1, `counter_lo` bắt đầu đếm từ 0. *Phụ thuộc:* không có match nào đang giữ, nên start một mình là đủ. *(Vì sao: `TIMER_START_LO` chỉ set `ENABLE`, không đụng các bit khác của `CFG_REG_LO`.)*

**Bước 7 — Counter đếm.** *Ở đâu:* `prescaler lo` và `counter_lo` trong TIMER1. *Làm gì:* prescaler bypass, mỗi cycle `HCLK` là một tick, count tăng 0, 1, 2, … *Đi tiếp:* mỗi cycle count được so bằng với `TIMER_CMP_LO`. *Phụ thuộc:* `ENABLE` = 1, `HCLK` có (gate mở), `PRESC_EN` = 0 nên đếm mỗi cycle. *(Vì sao: 1 ms chỉ là 20 000 cycle, còn 32-bit đếm mỗi cycle tới 214.7 s mới wrap, nên không cần prescaler. Prescaler chỉ cần cho khoảng dài hơn, tối đa 15.3 h.)*

**Bước 8 — Match, counter clear, interrupt lên.** *Ở đâu:* bộ compare của `counter_lo`, rồi `IRQ logic`. *Làm gì:* ở cycle count = 19 999, cycle sau `match_lo` (một flop) lên 1; vì `CMP_CLR` = 1, counter clear về 0 và chạy tiếp. *Đi tiếp:* `irq_lo_o` = `match_lo & IRQ_EN`, là 1-cycle pulse, ra `o_int_timer[0]`, vào `INTMAP`. *Phụ thuộc:* `IRQ_EN` = 1; compare là equality, nên `CMP` phải còn ở phía trước count; công thức chu kỳ MAS ghi confirm in simulation. *(Vì sao: `CMP_CLR` xóa counter ngay sau match flag, count rời `CMP` liền nên flag rơi: periodic luôn là 1-cycle pulse, kể cả prescaled. Compare là equality chứ không phải `>=` như `mtime`, nên một `CMP` mà count đã vượt qua thì phải đợi wrap, 214.7 s sau mới match.)*

**Bước 9 — INTMAP gom.** *Ở đâu:* `INTMAP`. *Làm gì:* OR `irq_lo_o` với `irq_hi_o` của TIMER1. *Đi tiếp:* ra `irq_fast_i[6]` của Ibex. *Phụ thuộc:* không có điều kiện nào, chỉ là cổng OR; `irq_hi_o` của TIMER1 cũng đi chung dây này. *(Vì sao: INTMAP cho mỗi block một line, mà TIMER1 có hai output, nên hai cái OR chung line 6.)*

**Bước 10 — Ibex trap.** *Ở đâu:* Ibex. *Làm gì:* nhận `irq_fast_i[6]`, trap với `mcause` 22. *Đi tiếp:* nhảy vào handler của TIMER1. *Phụ thuộc:* bit `mie` 22 và `mstatus.MIE` phải = 1 đúng lúc pulse lên. *(Vì sao: `mcause` chỉ cho biết block là TIMER1, không cho biết compare nào trong block. Mà IP không có status register nào ghi lại cái đó.)*

**Bước 11 — Handler xử lý và clear.** *Ở đâu:* handler trên Ibex. *Làm gì:* làm việc của tick. Pulse đã tự hết sau 1 cycle, không có gì phải clear; acknowledge bằng ghi vào block chỉ cần cho level one-shot (7.5). Rồi `mret`. *Đi tiếp:* quay về chương trình chính. *Phụ thuộc:* TIMER không có status register, periodic thì không biết `lo` hay `hi` kéo line 6 (Table 9-1). Ở ví dụ này `CFG_REG_HI.IRQ_EN` = 0, nên `irq_hi_o` = 0 và nguồn chắc chắn là `lo`. *(Vì sao: Ở periodic, lỡ một pulse thì kỳ sau lại có, nên pulse không cần giữ và không cần clear. Còn chuyện không biết `lo` hay `hi`, xem bước 10.)*

**Bước 12 — Chu kỳ sau.** *Ở đâu:* `counter_lo`. *Làm gì:* counter đã về 0 ở bước 8 và vẫn đếm. *Đi tiếp:* 20 000 cycle sau match lại lên, lặp lại bước 8 tới 11. *Phụ thuộc:* không cần firmware ghi gì thêm. *(Vì sao: Chính `CMP_CLR` làm counter thành periodic: nó xóa counter ở mỗi match, firmware không phải nạp lại gì.)*

**Kết thúc:** tick 1 ms chạy mãi mà firmware không phải đụng vào TIMER1, cho tới khi firmware xóa `ENABLE`, ghi reset, hoặc đóng gate. Không đóng gate khi interrupt đang lên (luật 4).

### Câu chuyện 2: `TIMER0` làm 64-bit time base

**Bước 1 — Reset, clock đã có sẵn.** *Ở đâu:* `SCRC`. *Làm gì:* nhả `o_rst_timer0_n`; gate TIMER0 mở sẵn sau reset. *Đi tiếp:* `HCLK` và `HRESETn` vào TIMER0; thanh ghi về 0, counter chưa chạy. *Phụ thuộc:* reset value "open" do `SCRC` owner làm (Table 11-1), nên firmware không cần ghi `SCRC` trước. *(Vì sao: TIMER0 là time base, thời gian phải chạy mà không cần firmware hỏi. Nếu gate đóng lúc đầu thì mọi timestamp trước lần ghi `SCRC` đầu tiên đều sai mà không ai biết.)*

**Bước 2 — Firmware cấu hình 64-bit.** *Ở đâu:* firmware, qua `P_BUS`, cổng `APB_M7`, base `0x8001_C000`. *Làm gì:* ghi `CFG_REG_LO` với `MODE_64` = 1, `CMP_CLR` = 0 (free-running), `REF_CLK_EN` = 0; `CFG_REG_HI` giữ 0; rồi ghi `TIMER_START_LO`. *Đi tiếp:* `counter_lo` đếm mỗi tick; `counter_hi` tăng qua đường `MODE_64 carry`, chỉ ở tick mà `TIMER_VAL_LO` = `0xFFFF_FFFF`. *Phụ thuộc:* `CFG_REG_LO` điều khiển tất cả; `CFG_REG_HI.ENABLE` = 1 lúc `CFG_REG_LO.ENABLE` = 0 sẽ chạy `hi` một mình. *(Vì sao: Time base không được wrap: 32-bit wrap sau 214.7 s, firmware phải đếm số lần wrap, lỡ một lần là sai mọi timestamp sau đó; 64-bit thì khoảng 29 000 năm. Cái giá là instance chỉ còn một interrupt, nên TIMER1 được giữ làm hai timer 32-bit cho các timeout ngắn.)*

**Bước 3 — Firmware đọc thời gian.** *Ở đâu:* firmware, qua `APB_M7`. *Làm gì:* đọc `TIMER_VAL_HI` (`0x0C`), `TIMER_VAL_LO` (`0x08`), rồi `TIMER_VAL_HI` lần nữa. *Đi tiếp:* hai `HI` bằng nhau thì ghép `{HI, LO}` là count 64-bit; khác nhau thì đọc lại. *Phụ thuộc:* luật 6; `lo` có thể wrap giữa hai lần đọc. *(Vì sao: Count 64-bit phải đọc bằng hai lần APB 32-bit riêng. Nếu `lo` wrap giữa hai lần đọc thì `HI` đã tăng, và hai lần đọc `HI` khác nhau là dấu hiệu để đọc lại.)*

**Bước 4 — Hẹn giờ một sự kiện (tuỳ chọn).** *Ở đâu:* firmware, rồi TIMER0, `INTMAP`, Ibex. *Làm gì:* lấy count vừa đọc cộng khoảng chờ và margin, ghi `TIMER_CMP_HI`/`TIMER_CMP_LO`, bật `IRQ_EN`. *Đi tiếp:* khi cả hai nửa bằng compare, `irq_lo_o` = `match_lo & match_hi & IRQ_EN` → line 10 → `irq_fast_i[10]` → `mcause` 26; `irq_hi_o` luôn 0. *Phụ thuộc:* bit `mie` 26; compare đã bị vượt thì chỉ match sau 2^64 tick (luật 1). *(Vì sao: Lý do equality như bước 8 câu chuyện chính, nhưng ở 64-bit một giá trị đã bị vượt là khoảng 29 000 năm, tức là không bao giờ. Nên tính compare từ count mới là chuyện đúng sai chứ không phải chuyện hiệu năng.)*

**Kết thúc:** count 64-bit chạy suốt, không wrap trong đời chip. Nó chỉ dừng khi reset, hoặc khi đóng gate TIMER0, và việc dừng đó không để lại dấu (luật 5).

### Câu chuyện 3: one-shot trên `TIMER1` counter `hi`, có prescaler

**Bước 1 — Cấu hình và start.** *Ở đâu:* firmware, qua `APB_M8`. *Làm gì:* ghi `TIMER_CMP_HI`; ghi `CFG_REG_HI` với `ONE_SHOT` = 1, `CMP_CLR` = 0, `PRESC_EN` = 1, `PRESC` >= 1, `IRQ_EN` = 1; ghi `TIMER_START_HI`. *Đi tiếp:* `counter_hi` đếm một tick mỗi `PRESC`+1 cycle. *Phụ thuộc:* gate TIMER1 đã mở; `CFG_REG_HI[31]` = 0, nếu không counter `hi` không tự clear `ENABLE`. *(Vì sao: RTL đọc `CFG_REG_HI[31]` trong đường one-shot của counter `hi`. Bit này = 1 ở 32-bit mode thì counter `hi` không tự clear `ENABLE` khi match nữa.)*

**Bước 2 — Match và dừng.** *Ở đâu:* `counter_hi`, `IRQ logic`, `INTMAP`. *Làm gì:* count = `CMP`, `ONE_SHOT` clear `ENABLE`; cycle đó không có tick nên counter đứng ở `CMP`, `match_hi` giữ 1. *Đi tiếp:* `irq_hi_o` là level → OR → `irq_fast_i[6]` → `mcause` 22. *Phụ thuộc:* có prescaler mới ra level; không prescaler thì counter dừng ở `CMP`+1 và chỉ ra 1-cycle pulse. MAS ghi confirm in simulation. *(Vì sao: Match flag không bị `ENABLE` chặn; có prescaler thì cycle ngay sau match không có tick, counter đứng ở `CMP` nên flag giữ 1. Level này có ích: one-shot không có "kỳ sau", nên alarm lỡ lúc `mstatus.MIE` tắt vẫn còn pending khi bật lại.)*

**Bước 3 — Handler tìm nguồn.** *Ở đâu:* handler trên Ibex. *Làm gì:* đọc `CFG_REG_HI`. *Đi tiếp:* counter đã start mà `ENABLE` = 0 là counter đã match. *Phụ thuộc:* cách này chỉ đúng ở one-shot (7.5). *(Vì sao: Không có status register (xem bước 10 câu chuyện chính). Chỉ ở one-shot, match tự clear `ENABLE`, nên `ENABLE` = 0 mới thành dấu vết.)*

**Bước 4 — Clear trước `mret`.** *Ở đâu:* handler, qua `APB_M8`. *Làm gì:* ghi `TIMER_RESET_HI` (hoặc `CFG_REG_HI.RESET` = 1, hoặc ghi `CMP`/`VAL` cho khác nhau, hoặc `IRQ_EN` = 0). *Đi tiếp:* count khác compare, level rơi, `irq_fast_i[6]` về 0, rồi `mret`. *Phụ thuộc:* không clear thì handler bị gọi lại; gate phải còn mở, vì gate đóng thì level giữ mà không ghi được. *(Vì sao: Counter đứng ở `CMP` nên level không tự rơi; về `mret` mà chưa clear thì Ibex vào lại handler ngay. Gate đóng thì counter và flag giữ nguyên mà block lại không ghi được, nên level kẹt luôn.)*

**Bước 5 — Chạy lại khi cần.** *Ở đâu:* firmware. *Làm gì:* ghi `TIMER_RESET_HI` rồi `TIMER_START_HI` (luật 7). *Đi tiếp:* counter đếm lại từ 0. *Phụ thuộc:* ghi `TIMER_START_HI` một mình không đủ, vì điều kiện one-shot lại clear `ENABLE`. *(Vì sao: Count vẫn bằng `CMP`, điều kiện one-shot vẫn đúng, nên ghi `TIMER_START_HI` một mình thì `ENABLE` bị clear lại ngay cycle sau. `TIMER_RESET_HI` đưa count về 0 trước, rồi start mới chạy.)*

**Kết thúc:** một interrupt duy nhất, counter đứng yên cho tới khi firmware reset rồi start lại.

| IP liên quan | TIMER cần gì từ IP đó |
|---|---|
| `SCRC` | clock gate `CLK_EN` (`TIMER0` mở, `TIMER1` đóng lúc reset), reset `o_rst_timer0_n` / `o_rst_timer1_n`, error responder khi gate đóng; vị trí bit `CLK_EN` và `SOFT_RST_CTRL` còn TBD |
| `P_BUS` (APB) | port `APB_M7` / `APB_M8`, vùng 16 KiB mỗi instance, `i_bus_apb_paddr[11:0]` = 12 bit thấp của offset |
| `INTMAP` | line 10 cho `TIMER0.irq_lo_o`; line 6 = OR của `TIMER1.irq_lo_o` và `irq_hi_o` |
| Ibex | `irq_fast_i[10]` / `[6]`, bit `mie` 26 / 22, `mstatus.MIE`, handler clear level trước `mret` |

## 3. Giải thích từng hình

### Figure 3-1. TIMER0 and TIMER1 in QSOC

Hình này trả lời: hai TIMER nằm đâu trong chip, lấy bus, clock, reset từ đâu, và interrupt đi về đâu.

Thưa thầy, em đọc từ trên xuống. (Trong script, dấu `|` là chỗ xuống dòng trong hộp.)

Trên cùng là khối **"P_BUS (APB4, 20 MHz)"**. Đây là bus APB của các peripheral, chạy 20 MHz. Từ nó đi xuống hai mũi tên. Mũi tên **`APB_M7`** vào TIMER0. Mũi tên **`APB_M8`** vào TIMER1. Đây là đường firmware đọc ghi thanh ghi.

Bây giờ em sang phía TIMER0, bên trái.

Khối giữa ghi **"TIMER0 | apb_timer_unit | 0x8001_C000 | MODE_64 = 1"**. Đây là instance thứ nhất của IP `apb_timer_unit`, đặt ở base `0x8001_C000`. Chữ `MODE_64 = 1` là firmware ghi vào, không phải tham số phần cứng.

Bên trái nó có hai khối của `SCRC`. Khối trên ghi **"SCRC clock gate | CLK_EN[TBD] | open at reset"**. Đây là clock gate của TIMER0, mở sẵn sau reset; vị trí bit `CLK_EN` còn TBD. Nó ra mũi tên **`HCLK`** vào TIMER0. Khối dưới ghi **"SCRC | o_rst_timer0_n"**. Đây là reset riêng của TIMER0, ra mũi tên **`HRESETn`** vào TIMER0.

Phía dưới TIMER0 có một khối ghi **"event_lo_i = 0 | event_hi_i = 0 | ref_clk_i = 0"**, với mũi tên đi lên TIMER0. Đây là tie-off: không có nguồn start phần cứng, không có reference clock trong QSOC.

Từ đáy TIMER0 đi ra ba mũi tên. Mũi tên **`irq_hi_o`** đi vào khối **"n.c."**, tức là để hở, vì ở 64-bit mode `irq_hi_o` luôn bằng 0. Mũi tên **`busy_o`** đi vào một khối **"n.c."** khác, vì không ai dùng `busy_o`. Mũi tên **`irq_lo_o`** đi thẳng xuống vào INTMAP.

Sang phía TIMER1, bên phải, cấu trúc giống hệt.

Khối giữa ghi **"TIMER1 | apb_timer_unit | 0x8002_0000 | MODE_64 = 0"**. Cùng IP, base `0x8002_0000`, chạy hai counter 32-bit riêng.

Bên trái có **"SCRC clock gate | CLK_EN[TBD] | closed at reset"**, ra mũi tên **`HCLK`**. Khác TIMER0 đúng ở chữ **closed**: gate TIMER1 đóng sau reset, firmware phải mở trước khi dùng. Khối dưới **"SCRC | o_rst_timer1_n"** ra mũi tên **`HRESETn`**.

Phía dưới lại có khối tie-off **"event_lo_i = 0 | event_hi_i = 0 | ref_clk_i = 0"**, mũi tên đi lên TIMER1.

Từ đáy TIMER1 đi ra ba mũi tên. **`busy_o`** vào khối **"n.c."**. Còn **`irq_lo_o`** và **`irq_hi_o`** cả hai đều đi xuống INTMAP.

Cuối cùng là khung nét đứt ghi **"INTMAP"**. Đây là khối gom interrupt, chỉ có dây và cổng OR.

Bên trái trong INTMAP, `irq_lo_o` của TIMER0 vào thẳng khối **"irq_fast_i[10] | mcause 26"**. Đó là input fast interrupt số 10 của Ibex, trap với `mcause` 26.

Bên phải, `irq_lo_o` và `irq_hi_o` của TIMER1 vào khối **"OR"**. Từ OR một mũi tên đi xuống khối **"irq_fast_i[6] | mcause 22"**, tức input số 6 của Ibex, `mcause` 22.

Tóm lại: hai TIMER là cùng một IP, mỗi cái có port APB, clock gate và reset riêng từ `SCRC`. Khác nhau ở ba chỗ: `MODE_64` do firmware ghi, gate mở hay đóng sau reset, và line INTMAP. TIMER0 đưa một interrupt lên line 10; TIMER1 OR hai interrupt lên line 6.

**Hỏi:** Sao dùng hai instance mà không dùng một block hai timer?
**Đáp:** Hệ thống cấp hai APB port và hai bit clock gate. Nhờ vậy hai timer tắt được độc lập.

**Hỏi:** Sao TIMER0 mở gate lúc reset, còn TIMER1 đóng?
**Đáp:** TIMER0 là time base, không phải chờ firmware ghi `SCRC` mới chạy được. TIMER1 dùng cho timeout, chỉ cần khi firmware bật.

**Hỏi:** Hai interrupt của TIMER1 OR chung thì mất gì?
**Đáp:** Mất khả năng biết nguồn. Không có status register, nên ở periodic hay free-running firmware không phân biệt được `lo` hay `hi`.

### Figure 3-2. Inside one TIMER instance

Hình này trả lời: bên trong một `apb_timer_unit` có gì, và từ tick tới interrupt đi qua những khối nào.

Thưa thầy, em đi từ trái sang phải.

Ngoài cùng bên trái là khối **"ref_clk_i"**. Đây là input reference clock của IP. Trong QSOC nó tie 0. Một mũi tên đi sang khối kế tiếp.

Khối đó ghi **"ref_clk_i | sync + edge | 4 flops"**. Đây là khối đồng bộ `ref_clk_i` và bắt cạnh lên của nó. Nó ra hai mũi tên cùng tên **`ref edge`**: một lên `prescaler lo`, một xuống `prescaler hi`. Vì `ref_clk_i` = 0 nên trong QSOC không có cạnh nào, và `REF_CLK_EN` = 1 làm counter dừng.

Tiếp theo là hai prescaler. Khối trên ghi **"prescaler lo | / (PRESC+1) | bypass when PRESC_EN = 0"**. Đây là bộ chia 8-bit của counter `lo`: một tick mỗi `PRESC`+1 cycle, hoặc bypass khi `PRESC_EN` = 0 để tick mỗi cycle. Nó ra mũi tên **`tick`** vào `counter_lo`. Khối dưới ghi **"prescaler hi | / (PRESC+1) | bypass when PRESC_EN = 0"**, giống hệt, ra mũi tên **`tick`** vào `counter_hi`.

Ở giữa hình là khối **"APB register file | CFG_REG TIMER_VAL TIMER_CMP | TIMER_START TIMER_RESET"**. Đây là các thanh ghi firmware thấy. Nó ra hai mũi tên **`CFG`**, một lên `prescaler lo`, một xuống `prescaler hi`, mang `PRESC_EN` và `PRESC`. Nó ra hai mũi tên **`CMP`**, một lên `counter_lo`, một xuống `counter_hi`, mang giá trị compare.

Trên register file có khối **"event_lo_i | event_hi_i"**, mũi tên đi xuống register file. Đây là input start bằng phần cứng: khi `IEM` = 1 thì event set `ENABLE`. Trong QSOC nó tie 0 nên không có tác dụng.

Từ register file một mũi tên đi lên khối **"busy_o"**. Đây là output của IP, trong QSOC để hở vì không ai dùng.

Dưới register file là khối **"APB | PADDR[5:0]"**, mũi tên hai chiều với register file. Đây là cổng bus. IP chỉ decode `PADDR[5:0]`, nên map 64 byte lặp lại trong vùng 16 KiB.

Sang hai counter. Khối trên ghi **"counter_lo 32-bit | == TIMER_CMP_LO"**. Đây là counter 32-bit của `lo`, tăng mỗi tick, và so bằng với `TIMER_CMP_LO`. Cycle sau cycle count = `CMP`, match flag lên 1, kể cả khi `ENABLE` = 0. Nó ra hai mũi tên. Mũi tên **`match_lo`** sang `IRQ logic`. Mũi tên **`MODE_64 carry`** vòng xuống `counter_hi`: ở 64-bit mode, `counter_hi` chỉ tăng ở tick mà `counter_lo` = `0xFFFF_FFFF`.

Khối dưới ghi **"counter_hi 32-bit | == TIMER_CMP_HI"**. Đây là counter `hi`, so bằng với `TIMER_CMP_HI`. Nó ra mũi tên **`match_hi`** sang `IRQ logic`.

Tiếp theo là khối **"IRQ logic | IRQ_EN | MODE_64"**. Đây là logic tổ hợp. Ở 32-bit mode, mỗi match AND với `IRQ_EN` của nó. Ở 64-bit mode, `irq_lo_o` = `match_lo & match_hi & IRQ_EN`, còn `irq_hi_o` = 0. Nó ra hai mũi tên.

Ngoài cùng bên phải là hai khối **"irq_lo_o"** và **"irq_hi_o"**. Đây là hai output interrupt, ra `o_int_timer[0]` và `o_int_timer[1]` của wrapper, rồi vào INTMAP.

Tóm lại: tick đi từ `HCLK` hoặc `ref_clk_i`, qua prescaler, vào counter; counter so bằng với `CMP` rồi ra match; `IRQ logic` AND match với `IRQ_EN` thành interrupt. Register file ở giữa cấp `CFG` và `CMP` cho tất cả, và `MODE_64 carry` là thứ chain hai counter thành 64-bit.

**Hỏi:** Sao one-shot có prescaler lại thành level?
**Đáp:** Match flag không bị `ENABLE` chặn. Counter dừng ở `CMP` thì count vẫn bằng compare, flag giữ 1 tới khi firmware clear. MAS ghi confirm in simulation.

**Hỏi:** 64-bit chain làm sao cho đúng?
**Đáp:** Theo đường `MODE_64 carry`: `hi` tăng đúng ở tick mà `lo` = `0xFFFF_FFFF`, có hay không có prescaler.

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
- Dòng cần chỉ: interrupt status = **nowhere**; acknowledge = firmware ghi vào block (7.5); nguồn của `irq_fast_i[6]` = nowhere ở periodic hoặc free-running; error response = `SCRC` responder, chỉ khi gate đóng; compare >= = nowhere; `mtime`/`mtimecmp` = nowhere, `irq_timer_i` tie 0 ở core; gom lên line CPU = `INTMAP`.

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

## 5. Vì sao con số này

| Con số | Ở đâu (bảng/hình) | Vì sao | Nếu khác thì sao |
|---|---|---|---|
| 2 instance (`TIMER0`, `TIMER1`) | Table 1-1, Figure 3-1 | HAS cấp hai APB port và hai bit clock gate riêng. Hai vai trò khác nhau: một time base 64-bit và hai timer 32-bit cho timeout. | Một block thì chung một gate: không dừng được timer timeout mà không dừng luôn time base. |
| counter 32-bit | Figure 3-2, Table 6-1 | Cố định trong IP: `timer_unit_counter` là 32-bit. Với timer thì đủ: 2^32 / 20 MHz = 214.7 s. | 16-bit như `apb_adv_timer` thì wrap sau 2^16 / 20 MHz = 3.2768 ms; firmware phải đếm wrap liên tục (DECISIONS). |
| 64-bit trên `TIMER0` | Table 1-1, Figure 3-1 | Time base không được wrap: 2^64 / 20 MHz = 9.22 x 10^11 s, khoảng 29 000 năm. Cái giá là chỉ còn một interrupt. | Để 32-bit thì 214.7 s wrap một lần; lỡ một lần wrap là sai mọi timestamp sau đó. |
| `MODE_64` = 1 / = 0 | Table 1-1, Figure 3-1 | Firmware ghi, không phải parameter. `TIMER0` = 1 để có time base; `TIMER1` = 0 để có hai timer, hai interrupt. | `TIMER1` = 1 thì mất một timer và `irq_hi_o` = 0; `TIMER0` = 0 thì time base wrap sau 214.7 s. |
| `0x8001_C000`, `0x8002_0000`; `APB_M7`, `APB_M8` | Table 1-1, Figure 3-1 | Chọn theo HAS: mỗi peripheral một vùng 16 KiB (`0x4000`), xếp liền nhau; `TIMER0` ở vùng sau `0x8001_8000` (vùng này trước là `GPIO3`, nay bỏ trống vì QSoC chỉ còn 3 GPIO; giữ nguyên để không phải dời địa chỉ nào), `TIMER1` ngay sau `TIMER0`. Port đánh số theo cùng thứ tự đó. | Đổi là đổi memory map của chip: HAS, `P_BUS` decode và firmware header phải đổi theo. |
| line 10 / line 6; mcause 26 / 22 | Table 1-1, Figure 3-1 | Chọn theo quy ước INTMAP: thứ tự line là "data loss first, human time last", mà tick timer lỡ thì kỳ sau lại có, nên timer nằm ở nửa ưu tiên thấp. `mcause` = 16 + line: 16 + 10 = 26, 16 + 6 = 22. | Ibex lấy index thấp nhất trước, nên đổi line là đổi priority và `mcause`, và phải synthesis lại. |
| `irq_fast_i[6]` nhận 2 nguồn | Table 1-1, Table 9-1, Figure 3-1 | INTMAP cho mỗi block một line; `TIMER1` có hai output nên OR vào một line. | Tách hai line thì `mcause` phân biệt được `lo`/`hi`, nhưng tốn thêm một line và đổi contract INTMAP. |
| `4c69615c`, SolderPad 0.51 | Table 4-1 | Commit của `pulp-platform/timer_unit` đã vendor và đọc RTL; licence của repo đó. | Đổi commit thì mọi hành vi đọc từ RTL (one-shot, `CFG_REG_HI[31]`) phải kiểm lại. |
| `paddr` 12 bit | Table 5-1, Table 11-1 | IP có parameter `APB_ADDR_WIDTH = 12`; đã quyết định để 12 bit ở wrapper. `P_BUS` trừ base và đưa 12 bit thấp của offset; vùng 16 KiB cần 14 bit, nhưng bit 13:12 không dùng. | Rộng hơn cũng vô ích, vì IP chỉ decode `[5:0]`. |
| `PADDR[5:0]`, map 64 byte, lặp 256 lần, `base + 0x40` | Table 5-1, Figure 3-2 | Cố định trong IP: decode 6 bit, 2^6 = 64 byte. 16 KiB / 64 byte = 256 lần lặp; `0x40` có `[5:0]` = 0 nên trúng `CFG_REG_LO`. | Thu hẹp decode trong wrapper tốn logic mà chỉ đổi lấy một lỗi firmware không thấy được, vì `PSLVERR` luôn 0 (DECISIONS). |
| width 32 (`pwdata`, `prdata`) | Table 5-1 | Bus APB 32-bit, thanh ghi IP 32-bit. | Cố định trong IP, không đổi được. |
| `pstrb` 4, `pprot` 3 | Table 5-1, Table 10-1 | Độ rộng chuẩn APB4 của `P_BUS`: 32 / 8 = 4 byte lane; `pprot` 3 bit. IP không có hai input này nên để hở. | Byte hay halfword store vẫn ghi cả 32 bit; vì vậy chỉ dùng word store. |
| `o_int_timer` 2 bit, `[0]` = `irq_lo_o`, `[1]` = `irq_hi_o` | Table 5-1 | Một bit cho mỗi output interrupt của IP, theo thứ tự `lo` rồi `hi`. | `TIMER0` chỉ dùng `[0]`; `[1]` để hở ở INTMAP. |
| `PREADY` = `PSEL & PENABLE`, zero wait state; `PSLVERR` = 0 | Table 5-1 | Cố định trong IP. Hệ quả: block không bao giờ làm treo `P_BUS`, nhưng cũng không bao giờ báo lỗi (DECISIONS). | Truy cập sai offset không có lỗi nào: ghi bị bỏ, đọc ra 0. |
| offset `0x00`-`0x24`, bước 4; `0x28`-`0x3C` RSVD | Table 6-1 | Cố định trong IP (khối `` `define `` đầu `apb_timer_unit.sv`). Mười thanh ghi 32-bit, word-aligned nên cách nhau 4 byte, xếp theo cặp `lo`/`hi`; phần còn lại của 64 byte là RSVD. | Cố định trong IP, không đổi được; driver dùng đúng các offset này. |
| bit 0-7 là cờ, `PRESC` bit 15:8, `MODE_64` bit 31, bit 30:16 không chức năng | Table 6-1 | Cố định trong IP (`ENABLE_BIT` = 0 … `REF_CLK_EN_BIT` = 7, `PRESCALER_START_BIT` = 8, `PRESCALER_STOP_BIT` = 15, `MODE_64_BIT` = 31). Thanh ghi lưu cả 32 bit, nên bit 30:16 đọc lại được mà không làm gì. | Cố định trong IP, không đổi được. |
| `CFG_REG_HI[31]` phải = 0 | Table 6-1 | RTL đọc bit này trong đường one-shot của counter `hi`. | = 1 ở 32-bit mode thì counter `hi` không tự clear `ENABLE` khi match. |
| reset = 0 cho mọi thanh ghi | Table 6-1 | Cố định trong IP. Sau reset không counter nào chạy, không interrupt nào bật. | Gate `TIMER0` mở sẵn nhưng counter vẫn chờ firmware ghi `CFG` và start. |
| `RESET` "returns to 0 the next cycle" | Table 6-1 | RTL tự xóa bit `RESET` sau một cycle. | Firmware không phải ghi 0 lại. |
| `PRESC` 8-bit, tick mỗi `PRESC`+1 | Table 6-1, Table 7-1, Figure 3-2 | Cố định trong IP (bit 15:8). `+1` vì `PRESC` = 0 nghĩa là chia 1, tức tick mỗi cycle. 8 bit là đủ: tối đa 15.3 h, trong QSOC không có gì đo lâu hơn (DECISIONS). | Cần dài hơn 15.3 h thì 32-bit có prescaler không đủ; dùng time base 64-bit. |
| 20 MHz | Table 7-1, Figure 3-1 | Chip chỉ có một tần số, không có PLL (contract); `HCLK` của TIMER là clock `peri` đã gate. | Mọi thời gian trong bảng tính theo 20 MHz; đổi tần số thì tính lại. |
| 214.7 s | Table 7-1 | 2^32 / 20 MHz = 4 294 967 296 / 20 000 000 = 214.7 s. | Là khoảng chờ nếu `CMP` đã bị vượt ở 32-bit (7.4). |
| 15.3 h | Table 7-1 | 214.7 s x 256 (`PRESC` = 255) = 54 976 s = 15.3 h. | Là giới hạn trên của timer 32-bit. |
| "never" (`REF_CLK_EN` = 1) | Table 7-1 | `ref_clk_i` tie 0 nên không có cạnh lên nào, counter không tăng. | Tie 0 thay vì nối clock: hành vi như nhau khi `REF_CLK_EN` = 0, và không kéo clock net vào chân data của flop (DECISIONS). |
| 4 flops (`ref_clk_i sync + edge`) | Figure 3-2 | Theo RTL: 2 flop đầu đồng bộ `ref_clk_i` vào `HCLK`, flop thứ 3 để bắt cạnh lên, flop thứ 4 tạo cạnh trễ thêm một cycle, dùng cho carry của counter `hi` ở 64-bit mode khi đếm `ref_clk_i`. `ref_clk_i` được lấy mẫu như data, không phải clock. | Cố định trong IP; trong QSOC không có tác dụng vì `ref_clk_i` = 0. |
| `0xFFFF_FFFF` (`MODE_64 carry`) | Figure 3-2, 7.2 | Giá trị lớn nhất của 32-bit: `hi` tăng đúng ở tick mà `lo` wrap về 0. | Là cách chain cho ra count 64-bit thật, không phải hai nửa rời. |
| 1-cycle pulse; pulse of one tick | Table 7-3 | Periodic: `CMP_CLR` xóa counter ngay sau match. Free-running prescaled: counter đứng ở `CMP` trọn một tick = `PRESC`+1 cycle. | Pulse ngắn nhất là 1 cycle `HCLK`; INTMAP phải giả định trường hợp này (DECISIONS). |
| `CMP`+1 (điểm dừng one-shot) | Table 7-3 | `ENABLE` đã register vẫn = 1 thêm một cycle sau match, nên counter đếm mỗi cycle nhích thêm một bước. Confirm in simulation. | Có prescaler thì cycle đó không có tick, counter dừng ở `CMP` và thành level. |
| `CMP` >= 1 | Table 7-4 | MAS chỉ cho công thức chu kỳ với `CMP` >= 1. | `CMP` = 0 không được mô tả. |
| `CMP`+1 cycle | Table 7-4 | Counter đi 0, 1, …, `CMP`: `CMP`+1 giá trị, mỗi giá trị một cycle. Ví dụ 20 000 cycle = 1 ms ⇒ `CMP` = 19 999. Confirm in simulation. | Nếu viết `CMP` = 20 000 thì chu kỳ là 20 001 cycle. |
| `CMP` x (`PRESC`+1) cycle | Table 7-4 | Theo RTL: clear đến ngay sau match flag, không đợi hết tick, nên không có tick thêm như ở `CMP`+1. Confirm in simulation. | Dùng (`CMP`+1) x (`PRESC`+1) thì tính sai một tick. |
| 2^32 / 2^64 tick | Table 7-4 | Free-running không clear, nên chỉ match lại sau khi counter wrap hết vòng 32-bit hoặc 64-bit. | Là cái giá của compare equality: `CMP` đã bị vượt phải chờ hết vòng. |
| `irq_timer_i` tie 0 | Table 9-1 | QSOC không có `mtime`/`mtimecmp`; tick đi đường fast interrupt. Hợp lệ, vì machine timer là tiện ích của platform (DECISIONS). | RTOS port phải tự viết timer driver; không có RTOS nào trong scope. |
| `event_lo_i`, `event_hi_i`, `ref_clk_i` = 0 | Table 10-1, Figure 3-1 | Không block nào cần start bằng phần cứng; không có reference clock. | Nối lại event là một dây; bit `IEM` đã có sẵn. |
| `CLK_EN[TBD]` | Figure 3-1, Table 11-1 | Vị trí bit do `SCRC` owner quyết, chưa có. | Chặn việc nối clock và reset của wrapper. |
| bit 13:12 của offset không dùng | Table 11-1 | Vùng 16 KiB cần 14 bit offset, nhưng wrapper chỉ nhận 12 bit và IP chỉ decode `[5:0]`. | Không ảnh hưởng: aliasing đã được chấp nhận. |
| V2.0, V2.1; ngày 2026-09-23 / 24 | Revision history, Table B-1 | Số phiên bản và ngày của MAS và của lần review đầu. | — |
