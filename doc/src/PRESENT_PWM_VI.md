# Thuyết trình PWM — bản đọc
**Khớp tài liệu:** `QNSC_PWM_MAS` V2.1 · **Ngày:** 2026-09-24

## 1. PWM là gì

PWM (Pulse Width Modulation) là tạo một xung vuông có period cố định.
Firmware chỉnh độ rộng phần mức 1, tức duty cycle, để điều khiển công suất trung bình: độ sáng LED, tốc độ motor.
Trong QSOC, PWM là một instance của `pulp-platform/apb_adv_timer` trên `APB_M13`, tại `0x80034000`, 16 KiB.
Bên trong có 4 timer module, mỗi module 4 channel, tổng 16 channel output; 8 channel của module 0 và 1 ra pad `PWM_0..7`, và 4 event line đi vào `INTMAP` fast line 7.

## 2. Flow end-to-end

### Câu chuyện chính: tạo PWM 20 kHz, duty 75% trên `PWM_0`

Clock là 20 MHz, một cycle 50 ns. Ta dùng module 0, channel 0.

**Bước 1 — Power-on.** *Ở đâu:* toàn chip, reset `i_rst_n_peri` vào PWM. *Làm gì:* mọi register về giá trị reset: `CH_EN` = 0, `EVENT_CFG` = 0, `CFG.SAW` = 1, các field khác 0. *Đi tiếp:* `o_pwm` = 0 ra IO MUX, `o_int_pwm` = 0 ra `INTMAP`. *Phụ thuộc:* không có gì; out of reset cả 4 module đều dừng và không có clock. *(Vì sao: `EVENT_CFG` reset 0 nên block không thể ngắt một hệ thống chưa hề yêu cầu nó. `o_pwm` bằng 0 trong reset, nên pad không bị lái trước khi firmware lập trình.)*

**Bước 2 — SCRC mở clock cho PWM.** *Ở đâu:* firmware ghi register của `SCRC`. *Làm gì:* bật bit PWM trong `CLK_EN` và nhả bit PWM trong `SOFT_RST_CTRL`. *Đi tiếp:* `i_clk_peri` chạy vào PWM: register file, event mux và 4 clock gates. *Phụ thuộc:* vị trí bit của PWM trong hai register này do SCRC owner chốt (Table 11-1). *(Vì sao: Clock gate của PWM được phép đóng sẵn sau reset, vì block chưa làm được gì hữu ích khi chưa lập trình.)*

**Bước 3 — Firmware mở clock cho module 0.** *Ở đâu:* firmware qua `P_BUS`, `APB_M13` vào `adv_timer_apb_if`. *Làm gì:* ghi `CH_EN` (`0x80034104`) = `0x1`, tức `CLK_EN[0]` = 1. *Đi tiếp:* clock gate thứ 0 mở, `timer_module 0` có clock. *Phụ thuộc:* `CH_EN` reset 0, nên nếu chưa ghi thì mọi `CMD` gửi tới module 0 đều mất. *(Vì sao: Chọn `apb_adv_timer` vì nó là APB slave cắm thẳng vào `P_BUS`, không cần adapter; PWM của OpenTitan là TL-UL, phải thêm bridge. `CH_EN` là enable của 4 cell `pulp_clock_gating`, và cell này bọc `prim_clock_gating` của OpenTitan — cùng port, Ibex đã dùng, nên synthesis map về một ICG cell của thư viện.)*

**Bước 4 — Cấu hình count source và prescaler.** *Ở đâu:* register `CFG` của module 0 (`0x80034004`). *Làm gì:* ghi `SAW` = 1 (saw-tooth), `PRESC` = 0 (chia 1), `IN_MODE` = 0 (đếm mỗi cycle), `CLK_SEL` = 0; giá trị `0x1000`. *Đi tiếp:* `input_stage` và prescaler của `timer_module 0`. *Phụ thuộc:* `CLK_SEL` phải là 0, vì `low_speed_clk_i` tie 0 nên `CLK_SEL` = 1 làm module không đếm. *(Vì sao: Wrapper chỉ nhận `paddr` 12 bit và IP decode `[9:2]`, nên window 1 KiB lặp lại mỗi `0x400` mà không báo lỗi. Nhóm chấp nhận alias này, vì không đáng tốn logic cho một lỗi firmware không quan sát được.)*

**Bước 5 — Đặt period.** *Ở đâu:* register `TH` của module 0 (`0x80034008`). *Làm gì:* START = 0, END = 999; giá trị `0x03E70000`. *Đi tiếp:* counter của module 0, được nạp khi có `CMD.START`. *Phụ thuộc:* thời điểm `TH` mới có hiệu lực khi đang chạy là mục MAS ghi "confirm in simulation". *(Vì sao: Counter 16 bit là đủ cho PWM: ở 20 MHz, 20 kHz vẫn có 1000 duty steps, 1 kHz có 20 000. Tần số thấp nhất là 305 Hz khi `PRESC` = 0, và 1.19 Hz khi chia tối đa.)*

**Bước 6 — Đặt compare value và MODE.** *Ở đâu:* `CH0_TH` của module 0 (`0x8003400C`). *Làm gì:* `TH` = 250, `MODE` = 2 (SETRST); giá trị `0x000200FA`. *Đi tiếp:* comparator 0 của module 0. *Phụ thuộc:* thời điểm `CHn_TH` mới có hiệu lực khi đang chạy cũng là "confirm in simulation". *(Vì sao: RTL của `timer_module` không instantiate `lut_4x4` hay `out_filter`, nên dạng output do `CHn_TH.MODE` quyết định. `CHn_LUT` chỉ lưu và đọc lại, ghi vào cũng không đổi output.)*

**Bước 7 — Cho chạy.** *Ở đâu:* `CMD` của module 0 (`0x80034000`). *Làm gì:* ghi START = `0x01`; bit này chỉ giữ một cycle rồi tự xoá. *Đi tiếp:* START, END, SAW được nạp vào counter và counter bắt đầu chạy. *Phụ thuộc:* `CH_EN[0]` = 1 từ Bước 3; nếu không, lệnh này không có tác dụng. *(Vì sao: Trong IP này start và stop chỉ đến từ `CMD`; tín hiệu ngoài chỉ là count source (xem câu chuyện TIM_EXT). Bit `CMD` tự xoá nên firmware không phải ghi 0 lại.)*

**Bước 8 — Counter chạy.** *Ở đâu:* bên trong `timer_module 0`. *Làm gì:* `IN_MODE` = 0 cho một count event mỗi cycle, prescaler cho qua hết; counter đếm 0, 1, … 999 rồi nạp lại 0. *Đi tiếp:* giá trị counter tới 4 comparator; firmware đọc được ở `COUNTER` (`M+0x2C`). *Phụ thuộc:* clock gate của module 0 vẫn mở. *(Vì sao: 16 bit đủ cho waveform (Bước 5) nhưng wrap sau 3.28 ms, vô dụng làm timebase. Vì vậy PWM là IP riêng `apb_adv_timer`, khác TIMER0/1 dùng `apb_timer_unit`.)*

**Bước 9 — Comparator tạo xung.** *Ở đâu:* comparator 0 của module 0. *Làm gì:* khi COUNTER = 250 thì output lên 1 (match); khi counter tới END thì output về 0 (second event). *Đi tiếp:* `ch_0_o[0]`. *Phụ thuộc:* `MODE` = 2 và `SAW` = 1, theo Table 7-1. *(Vì sao: QSOC mặc định saw-tooth, và verification phủ trường hợp đó. Centre-aligned (`SAW` = 0) chỉ là một bit cấu hình nên được giữ lại, nhưng ghi là available, chưa verify đầy đủ.)*

**Bước 10 — Ra pad.** *Ở đâu:* wrapper rồi IO MUX. *Làm gì:* `ch_0_o[0]` đi ra `o_pwm[0]`. *Đi tiếp:* IO MUX → pad `PWM_0`. *Phụ thuộc:* IO MUX phải chọn chức năng `PWM_0` trên pad đó; chân nào và default sau reset là việc của IO pad / IO MUX owner. *(Vì sao: Trong RTL, `ch_i_o[3:0]` là 4 channel của module `i`, nên đưa `ch_0_o` và `ch_1_o` ra pad là đưa trọn module 0 và 1: hai tần số nền độc lập, mỗi tần số 4 channel. IO MUX chỉ thấy `o_pwm[7:0]`; chân nào mang chức năng nào là bảng của pad owner, nên MAS không ghi số chân.)*

**Bước 11 — Dạng sóng trên pad.** *Ở đâu:* pad `PWM_0`. *Làm gì:* period 1000 cycle = 50 µs, tức 20 kHz; mức 1 khoảng 750 cycle ≈ 37.5 µs, tức duty ≈ 75%. *Đi tiếp:* ra mạch ngoài, ví dụ LED hay power stage. *Phụ thuộc:* module 0 vẫn chạy và có clock.

**Bước 12 — Safe stop.** *Ở đâu:* `CMD` của module 0. *Làm gì:* ghi STOP | RST = `0x0A`. *Đi tiếp:* cả 4 output của module 0 về 0, nên pad `PWM_0` về 0. *Phụ thuộc:* `CH_EN[0]` vẫn phải bằng 1 lúc ghi, không thì lệnh mất. *(Vì sao: Mỗi output là flip-flop `r_value` trong comparator, và block không có "idle level" nào, chỉ có mức lái cuối cùng. Gate khi đang chạy thì pad đóng băng ở một điểm bất kỳ của waveform: với LED thì vô hại, với motor driver có thể là đang dẫn; `CMD.RST` xoá flip-flop về 0 trước.)*

**Bước 13 — Gate clock.** *Ở đâu:* `CH_EN` rồi `SCRC`. *Làm gì:* ghi `CH_EN` = 0, sau đó `SCRC` đóng `CLK_EN` của PWM. *Đi tiếp:* module 0 và cả block hết clock; output giữ mức 0. *Phụ thuộc:* chỉ làm sau Bước 12; gate khi đang chạy thì output đóng băng ở mức hiện tại, không an toàn cho power stage. *(Vì sao: Cùng lý do Bước 12, nên Table 11-1 giao cho firmware owner: `SCRC` chỉ đóng clock PWM sau safe stop. Pad owner chỉ cần kiểm không có pull-up hay pull-down nào chống lại mức firmware để lại.)*

**Kết thúc:** pad `PWM_0` đã ra xung 20 kHz, duty ≈ 75%, rồi dừng an toàn ở mức 0 trước khi clock bị gate.

**Ví dụ tính** (công thức period ở MAS 7.1):

- `SAW` = 1: Period = (END − START + 1) × (PRESC + 1) = (999 − 0 + 1) × 1 = 1000 cycle = 50 µs → **20 kHz**.
- Duty với `MODE` 2: mức 1 từ COUNTER = 250 tới END, khoảng 750 / 1000 → **≈ 75%**. Muốn ≈ 25% thì đặt `TH` = 750.
- Đổi `PRESC` = 19: period × 20 = 1 ms → 1 kHz, duty giữ nguyên.
- `SAW` = 0 (centre-aligned), START = 0, END = 500: Period = 2 × (END − START) × (PRESC + 1) = 1000 cycle → vẫn 20 kHz.
- MAS chỉ ghi công thức period. Duty ở đây em suy ra từ Table 7-1, có thể lệch ±1 count.
- Khi nào `TH`, `CHn_TH`, `IN_SEL`, `IN_MODE`, `PRESC` mới có hiệu lực lúc đang chạy: MAS ghi **"confirm in simulation"** (mục 12, item 11).

### Câu chuyện event → interrupt

**Bước E1 — Chọn channel cho event line 0.** *Ở đâu:* `EVENT_CFG` (`0x80034100`). *Làm gì:* `SEL0` = 0 (channel index `4 × 0 + 0`, tức `ch_0_o[0]`), `EN[0]` = 1; giá trị `0x00010000`. *Đi tiếp:* event mux, line 0. *Phụ thuộc:* `EVENT_CFG` reset 0, nên chưa ghi thì không có event. Mỗi lần enable, nếu channel đang là 1 mà mẫu cuối là 0 thì ra một event — đúng với mọi lần enable, không chỉ lần đầu. *(Vì sao: Event line là mux 4-of-16 trên channel output, không phải 4 comparator riêng. Vì vậy channel của module 2 và 3 không bị phí: chúng vẫn làm nguồn event được.)*

**Bước E2 — Bắt rising edge.** *Ở đâu:* event mux. *Làm gì:* mỗi cycle `i_clk_peri` lấy mẫu `ch_0_o[0]`; mẫu mới là 1, mẫu cũ là 0 thì ra pulse đúng 1 cycle. *Đi tiếp:* `events_o[0]` = `o_int_pwm[0]` → `INTMAP`. *Phụ thuộc:* chỉ lấy mẫu khi `EN[0]` = 1; falling edge không tạo event. Với cấu hình ở trên, rising edge xảy ra ở COUNTER = 250, mỗi period một lần. *(Vì sao: Đây là edge detector cổ điển trong RTL: mẫu mới AND nghịch đảo mẫu cũ, nên pulse đúng 1 cycle và chỉ có rising edge. Interrupt nghĩa là "channel em chọn vừa lên 1", không phải hết period.)*

**Bước E3 — Vào core.** *Ở đâu:* `INTMAP`. *Làm gì:* gộp 4 event line của PWM vào fast line 7. *Đi tiếp:* Ibex, mcause 23. *Phụ thuộc:* nếu core không nhận event thì event đó mất, không được ghi ở đâu. *(Vì sao: `timer_module.status_o` không nối vào register file, nên không có status để ghi lại event bị lỡ. Cách phục hồi là tính chu kỳ: channel lại lên sau một period, vì vậy không được dùng event PWM làm thông báo một lần.)*

**Bước E4 — Firmware xử lý.** *Ở đâu:* interrupt handler trên Ibex. *Làm gì:* mcause chỉ cho biết là PWM; firmware tự biết line 0 là `ch_0_o[0]` vì chính nó đã chọn. *Đi tiếp:* không có gì để đọc hay xoá ở PWM. *Phụ thuộc:* PWM không có event status register. *(Vì sao: 4 nguồn trên một fast line khớp với giả định của MAS INTMAP, nên interrupt contract không phải đổi. Cái giá là mcause chỉ xác định block, không xác định event.)*

**Kết thúc:** mỗi rising edge của `ch_0_o[0]` thành một interrupt trên fast line 7 của Ibex.

### Câu chuyện TIM_EXT → count source

**Bước T1 — Tín hiệu ngoài vào pad.** *Ở đâu:* pad `TIM_EXT0`, rồi IO MUX. *Làm gì:* IO MUX đưa tín hiệu pad vào PWM. *Đi tiếp:* `i_tim_ext[0]` vào wrapper. *Phụ thuộc:* IO MUX chọn chức năng `TIM_EXT0` trên pad đó (pad chia sẻ với GPIO). *(Vì sao: Nối theo thứ tự pad, `TIM_EXT0..3` = `ext_sig_i[3:0]`, vì dễ đọc: giá trị `IN_SEL` đoán được từ tên pad, không phải tra bảng. Về điện thì bốn bit nào cũng chạy.)*

**Bước T2 — Đồng bộ.** *Ở đâu:* 2FF sync trong wrapper. *Làm gì:* hai flip-flop đồng bộ tín hiệu về `i_clk_peri`. *Đi tiếp:* `ext_sig_i[0]`, index 0 của input pool. *Phụ thuộc:* `i_clk_peri` đang chạy, tức `SCRC` đã mở `CLK_EN`. *(Vì sao: `input_stage` lấy mẫu `ext_sig_i` mà không có synchroniser, nên `i_tim_ext` cần 2FF. Đặt 2FF trong wrapper PWM để không phụ thuộc vào IO MUX.)*

**Bước T3 — Làm count source.** *Ở đâu:* `input_stage` của module đã chọn nó. *Làm gì:* `CFG.IN_SEL` = 0, `CFG.IN_MODE` = 3: mỗi rising edge là một count event. *Đi tiếp:* prescaler rồi counter của module đó. *Phụ thuộc:* `CH_EN[i]` = 1 và đã `CMD.START`; start và stop chỉ đến từ `CMD`; `IN_MODE` 6 và 7 cần `CMD.ARM` trước. *(Vì sao: IP đã tự chọn count source cho từng module bằng `IN_SEL`, nên wrapper không cần thêm register chọn nào.)*

**Kết thúc:** counter đếm các edge ở pad `TIM_EXT0`; firmware đọc kết quả ở `COUNTER`.

| IP liên quan | PWM cần gì từ IP đó |
|---|---|
| `SCRC` | mở `CLK_EN` cho `i_clk_peri`, nhả reset; chỉ đóng clock sau safe stop |
| `P_BUS` (`APB_M13`) | APB4 tới block; `paddr[11:0]` là 12 bit thấp của offset (bus trừ base) |
| Ibex (firmware) | lập trình register; xử lý interrupt fast line 7 |
| IO MUX | đưa `o_pwm[7:0]` ra `PWM_0..7`, đưa `TIM_EXT0..3` vào `i_tim_ext`; chân và default sau reset do IO pad / IO MUX owner |
| `INTMAP` | gộp 4 event line vào fast line 7 |

## 3. Giải thích từng hình

### Figure 3-1. PWM block: register file, clock gates, four timer modules, event multiplexer

Hình này trả lời: bên trong PWM có gì, và mỗi tín hiệu vào, ra nối với ai trong chip.

Thưa thầy, em đi theo mũi tên từ trên xuống.

Trên cùng là ô **"P_BUS (APB)"**. Đây là bus peripheral của chip. Mũi tên đi xuống có nhãn **`APB_M13`**: đó là port của `P_BUS` nối vào PWM. Firmware chỉ chạm được PWM qua đường này.

Mũi tên đó đi vào khung nét đứt **"PWM apb_adv_timer 0x8003_4000"**. Khung này là toàn bộ block PWM, base address `0x80034000`.

Ô đầu tiên trong khung là **"APB register file adv_timer_apb_if"**, dòng dưới ghi **"CMD CFG TH CHn_TH CHn_LUT COUNTER EVENT_CFG CH_EN"**. Đây là toàn bộ register của block. Từ ô này có ba mũi tên ra:
- Mũi tên **`CH_EN`** sang trái, đi vào khối clock gates.
- Mũi tên **"config, per module"** đi xuống timer module. Hình vẽ tới module 0, nhưng nghĩa là cả 4 module, mỗi module có bộ register riêng.
- Mũi tên **`EVENT_CFG`** sang phải, đi vào event mux.

Bên trái là ô **"4 clock gates / one per module / en = CH_EN[i] / test_en = dft_cg_enable_i"**. Mỗi module có một clock gate; gate thứ `i` mở khi `CH_EN[i]` = 1. Từ ô này có bốn mũi tên không nhãn, mỗi mũi tên là clock riêng của một timer module; đó là mũi tên phía trên của mỗi module.

Giữa hình là bốn ô timer module. Ô đầu ghi **"timer_module 0 / input_stage (IN_SEL) / prescaler, 16-bit counter / 4 comparators"**. Tức là: chọn count source, chia bằng prescaler, đếm bằng counter 16 bit, rồi 4 comparator tạo 4 channel. Mũi tên ra có nhãn **`ch_0_o[3:0]`**, đi vào ô `16 ch`.
Ô **"timer_module 1"** giống hệt, mũi tên ra **`ch_1_o[3:0]`**.
Ô **"timer_module 2 (internal)"** và **"timer_module 3 (internal)"** cũng giống, ra **`ch_2_o[3:0]`** và **`ch_3_o[3:0]`**. Chữ "internal" nghĩa là hai module này không có pad.

Tiếp theo là ô **"16 ch"**. Đây là bus gộp 16 channel output. Từ ô này có bốn mũi tên:
- Mũi tên nhãn **`16`** đi lên event mux: cả 16 channel vào event mux.
- Mũi tên **`o_pwm[3:0]`** và **`o_pwm[7:4]`** sang phải vào IO MUX. Đây chỉ là `ch_0_o` và `ch_1_o`, tức module 0 và module 1.
- Mũi tên **`ch[15:0]`** đi xuống input pool: channel output quay lại làm count source được.

Phía trên bên phải là ô **"event mux / 4 x (16 : 1) / + rising edge"**. Đây là 4 bộ chọn 16:1; mỗi bộ chọn một channel theo `EVENT_CFG` rồi bắt rising edge. Mũi tên ra có nhãn **`events_o[3:0]`**, đi sang ô `INTMAP`.

Ô **"INTMAP / fast line 7 (mcause 23)"** nằm ngoài khung. `INTMAP` gộp 4 event line vào fast line 7 của Ibex, mcause 23.

Ô **"IO MUX"** bên phải ghi **"PWM_0 .. 3 = o_pwm[3:0]"** và **"PWM_4 .. 7 = o_pwm[7:4]"**. IO MUX chỉ thấy `o_pwm[7:0]` và đưa chúng ra 8 pad function `PWM_0..7`.

Dưới cùng là đường vào. Ô **"TIM_EXT0 .. 3 / pads"** là 4 pad trigger ngoài. Mũi tên không nhãn đi vào ô **"IO MUX"**. Từ IO MUX, mũi tên **`i_tim_ext`** vào ô **"2FF sync / i_clk_peri"**: hai flip-flop trong wrapper đồng bộ tín hiệu về `i_clk_peri`. Mũi tên ra **`ext_sig_i[3:0]`** đi lên input pool.

Ô **"input pool, 48 signals / ext_sig_i[31:0] + ch[15:0]"** là 32 input ngoài cộng 16 channel. Từ ô này một đường dọc đi lên, rẽ vào cả 4 timer module; đó là mũi tên phía dưới của mỗi module. `IN_SEL` của mỗi module chọn một trong 48 tín hiệu này.

Cuối cùng là các ô bên trái:
- **"i_clk_peri"**: clock `peri` cluster, đã qua gate `CLK_EN` của `SCRC`, đi vào clock gates.
- **"i_rst_n_peri"**: reset async active-low, mũi tên vào biên khung, tức reset cả block.
- **"dft_cg_enable_i = 0"**: tie-off, vào `test_en` của clock gates.
- **"low_speed_clk_i = 0"**: tie-off, vào biên khung; vì nó bằng 0 nên `CFG.CLK_SEL` = 1 làm module không đếm.
- **"ext_sig_i[31:4] = 0"**: tie-off, vào input pool; 28 input ngoài không dùng.

Tóm lại: firmware lập trình PWM qua `APB_M13`, mở clock từng module bằng `CH_EN`. Bốn module tạo 16 channel; module 0 và 1 ra 8 pad qua IO MUX, còn cả 16 channel đều vào được event mux và input pool. Event mux gửi 4 event line vào `INTMAP` fast line 7, và pad `TIM_EXT` vào qua IO MUX và 2FF sync làm count source.

**Hỏi:** 16 channel mà chỉ 8 ra pad, 8 cái kia để làm gì?
**Đáp:** Module 2 và 3 không có pad. Output của chúng chỉ vào event mux và input pool. Vì vậy pad có hai period độc lập, mỗi period 4 channel.

**Hỏi:** Vì sao cần ô 2FF sync?
**Đáp:** Pad `TIM_EXT` bất đồng bộ với `i_clk_peri`. Hai flip-flop trong wrapper đồng bộ nó trước khi thành `ext_sig_i[3:0]`.

**Hỏi:** 4 event line có nghĩa là 4 lần hết period không?
**Đáp:** Không. Mỗi event là rising edge của một channel firmware đã chọn trong `EVENT_CFG`.

**Hỏi:** Clock gate đóng thì output ra sao?
**Đáp:** Module giữ nguyên counter và output ở mức hiện tại. Vì vậy phải safe stop `CMD` = STOP | RST trước rồi mới gate.

## 4. Giải thích từng bảng

### Revision history (bảng không đánh số)

Bảng ghi phiên bản: V2.0 viết lại theo template; V2.1 sửa lại theo RTL. Lý do từng thay đổi nằm trong `QNSC_PWM_DECISIONS.md`.

### Table 4-1. Upstream IP used

- **Để làm gì:** ghi IP lấy từ ngoài, module nào, commit nào, licence gì.
- **Cột:** `From` = repo gốc; `Module` = các module SystemVerilog thực sự dùng; `Commit` = phiên bản cố định; `Licence` = điều kiện dùng.
- **Chỉ vào:** 8 module từ `apb_adv_timer` tới `comparator`, commit `c8faec1e`, SolderPad 0.51.
- Ghi chú dưới bảng: `lut_4x4.sv` và `out_filter.sv` có trong thư mục vendor nhưng không instantiated. `pulp_clock_gating` là wrapper của `prim_clock_gating` của OpenTitan, cùng cell Ibex đang dùng.

**Hỏi:** Vì sao không có `lut_4x4` và `out_filter`?
**Đáp:** RTL top không instantiate chúng. Hệ quả là `CHn_LUT` chỉ lưu và đọc lại, không ảnh hưởng output.

**Hỏi:** Clock gating cell lấy từ đâu?
**Đáp:** Từ `prim_clock_gating` của OpenTitan, bọc thành `pulp_clock_gating` trong `design/pwm/rtl`, cùng port.

### Table 5-1. PWM interface

- **Để làm gì:** liệt kê mọi port của wrapper `m_qnsc_wrap_apb_adv_timer`.
- **Cột:** `Signal` = tên port; `Dir` = in/out; `Width` = số bit; `Description` = nối đi đâu, hành vi gì.
- **Chỉ vào:**
  - `i_bus_apb_paddr`: 12 bit, nhưng chỉ `[9:2]` được decode.
  - `o_bus_apb_pready` luôn 1, `o_bus_apb_pslverr` luôn 0: không wait state, không lỗi.
  - `i_tim_ext`: 4 bit, qua 2FF rồi thành `ext_sig_i[3:0]`.
  - `o_pwm`: `[3:0]` = `ch_0_o`, `[7:4]` = `ch_1_o`.
  - `o_int_pwm`: 4 pulse 1 cycle tới `INTMAP` line 7.
- `o_pwm` và `o_int_pwm` bằng 0 trong reset.

**Hỏi:** Vì sao `i_tim_ext` cần 2FF?
**Đáp:** Pad bất đồng bộ với `i_clk_peri`. Hai flip-flop giảm metastability trước khi tín hiệu vào input stage.

**Hỏi:** `paddr` 12 bit mà chỉ decode `[9:2]`, phần còn lại thì sao?
**Đáp:** Window register 1 KiB lặp lại mỗi `0x400` trên cả region 16 KiB, không báo lỗi (MAS 7.6).

### Table 6-1. Register map

- **Để làm gì:** mọi register, field, bit, quyền truy cập và giá trị reset.
- **Cột:** `Offset` = địa chỉ tương đối (`M` = base module, `n` = channel); `Register`; `Field`; `Bits`; `Access` (WO/RW/RO); `Reset`; `Description`.
- **Chỉ vào:**
  - `CMD`: 5 bit WO — START, STOP, UPDATE, RST, ARM. Bit chỉ giữ trong cycle ghi; đọc `CMD` luôn ra 0.
  - `CFG.SAW` reset = 1: mặc định là saw-tooth. `CFG.PRESC` chia cho `PRESC + 1`.
  - `CHn_TH.MODE` 3 bit: output action (Table 7-1).
  - `CHn_LUT`: lưu và đọc lại, không tác dụng lên output.
  - `COUNTER`: RO, đọc giá trị counter hiện tại.
  - `EVENT_CFG` (`0x100`) và `CH_EN` (`0x104`): hai register chung cho cả block.
- Ví dụ offset: `CH2_TH` của module 1 = `0x040 + 0x0C + 4 × 2` = `0x054`, địa chỉ tuyệt đối `0x80034054`.

**Hỏi:** Vì sao safe stop là `0x0A`?
**Đáp:** STOP là bit 1 (`0x02`), RST là bit 3 (`0x08`). `0x02 | 0x08` = `0x0A`.

**Hỏi:** STOP và RST khác nhau thế nào?
**Đáp:** STOP dừng counter, output giữ mức. RST đưa counter về START, prescaler về 0, cả 4 output về 0.

**Hỏi:** Đổi `TH` khi đang chạy thì khi nào có hiệu lực?
**Đáp:** MAS ghi "confirm in simulation": tại `CMD.START`, tại `CMD.UPDATE` khi đang dừng, hoặc ở cuối period sau `CMD.UPDATE` khi đang chạy.

### Table 7-1. Channel output action, CHn_TH.MODE

- **Để làm gì:** với mỗi giá trị `MODE`, output làm gì khi match và khi có second event.
- **Cột:** `MODE` = giá trị 0..7; `Name`; `On match` = khi COUNTER = `CHn_TH.TH`; `On second event` = khi tới END (`SAW` = 1) hoặc match kế tiếp (`SAW` = 0). "--" là không làm gì.
- **Chỉ vào:**
  - MODE 2 SETRST: với `SAW` = 1 cho output edge-aligned; với `SAW` = 0 cho output centre-aligned. Đây là mode PWM thông dụng.
  - MODE 0, 3, 4 chỉ phản ứng khi match.
  - MODE 7 giữ nguyên.
- `CMD.RST` đưa output về 0 ở mọi MODE.

**Hỏi:** Muốn tín hiệu PWM bình thường thì chọn MODE nào?
**Đáp:** MODE 2: lên 1 khi match, về 0 ở second event. Duty do `CHn_TH.TH` quyết định.

**Hỏi:** MODE 0 (SET) thì output về 0 bằng cách nào?
**Đáp:** Chỉ bằng `CMD.RST`. Bảng không có action nào khác cho MODE 0.

### Table 7-2. Channel outputs against pad functions

- **Để làm gì:** channel nào của PWM ra chức năng pad nào.
- **Cột:** `Pad function` = tên chức năng pad; `Wrapper output` = bit của `o_pwm` mà IO MUX thấy; `Channel` = `ch_i_o[n]`, channel `n` của module `i` bên trong PWM.
- **Chỉ vào:** `PWM_0..3` = `o_pwm[3:0]` = 4 channel của module 0; `PWM_4..7` = `o_pwm[7:4]` = 4 channel của module 1. Bảng không ghi số PIN: đó là bảng của IO pad owner.

**Hỏi:** `PWM_0` và `PWM_4` chạy khác tần số được không?
**Đáp:** Được, vì thuộc hai module khác nhau, mỗi module có prescaler và `TH` riêng. `PWM_0` và `PWM_1` cùng module nên cùng period, chỉ khác compare value.

**Hỏi:** Ai quyết định pin là PWM hay GPIO?
**Đáp:** IO MUX. Default out of reset là việc còn mở của IO MUX owner (Table 11-1).

### Table 7-3. Input pool index, CFG.IN_SEL

- **Để làm gì:** `IN_SEL` chọn tín hiệu nào trong pool 48 tín hiệu làm count source.
- **Cột:** `IN_SEL` = chỉ số; `Signal` = tín hiệu được chọn.
- **Chỉ vào:**
  - 0..3 = `TIM_EXT0..3`.
  - 4..31 bị tie 0.
  - `32 + 4 × module + n` = output channel của module khác. Ví dụ channel 2 của module 1 là `32 + 4 + 2` = 38.
  - 48..255 là hằng 0.

**Hỏi:** Một module đếm theo output của module khác được không?
**Đáp:** Được, chọn `IN_SEL` từ 32 tới 47. Nhưng start và stop vẫn chỉ đến từ `CMD`.

### Table 7-4. Count source qualifier, CFG.IN_MODE

- **Để làm gì:** `IN_MODE` quyết định khi nào tín hiệu đã chọn tạo ra một count event.
- **Cột:** `IN_MODE` = giá trị 0..7; `A count event occurs` = điều kiện đếm.
- **Chỉ vào:**
  - 0 (reset): đếm mỗi cycle, bỏ qua tín hiệu. Đây là trường hợp PWM thường.
  - 3, 4, 5: đếm theo rising edge, falling edge, hoặc cả hai. Dùng để đếm xung ngoài.
  - 6, 7: cần `CMD.ARM` trước, rồi đếm mỗi cycle từ edge đầu tiên tới khi counter tới END.
- `CFG.CLK_SEL` = 1 cần thêm rising edge của `low_speed_clk_i`, nhưng input này tie 0, nên module đó không đếm.

**Hỏi:** `IN_SEL` chọn tín hiệu tie 0 thì module có đếm không?
**Đáp:** Chỉ với `IN_MODE` 0 (bỏ qua tín hiệu) và 1 (đếm khi tín hiệu bằng 0). Các mode khác không bao giờ đếm.

**Hỏi:** Đếm xung ở `TIM_EXT0` thì cấu hình ra sao?
**Đáp:** `IN_SEL` = 0, `IN_MODE` = 3. Mỗi rising edge sau 2FF là một count event.

### Table 9-1. Functions this block does not provide

- **Để làm gì:** nói rõ chức năng nào không có, và nếu có thì ai lo.
- **Cột:** `Function` = chức năng; `Where it lives` = ở đâu, hoặc "Nowhere".
- **Chỉ vào:** không có event status, không có period-end interrupt — "Nowhere". Gộp 4 event là việc của `INTMAP`; pad mux là việc của IO MUX.

**Hỏi:** Nếu core không kịp nhận một event thì sao?
**Đáp:** Event đó mất, không được ghi ở đâu. `timer_module.status_o` không nối vào register file. Channel chạy theo chu kỳ nên period sau sẽ có edge mới.

### Table 10-1. Tie-offs

- **Để làm gì:** các port của IP được nối cố định trong wrapper, và lý do.
- **Cột:** `Port`; `Tied to` = giá trị nối; `Why`.
- **Chỉ vào:**
  - `dft_cg_enable_i` = 0: pad ring không có nguồn test-mode, nên 4 clock gate chỉ theo `CH_EN`.
  - `low_speed_clk_i` = 0: không có clock chậm.
  - `ext_sig_i[31:4]` = 0: chỉ có 4 pad `TIM_EXT`.
  - `ch_2_o`, `ch_3_o` để hở ở biên wrapper: không có pad.

**Hỏi:** Tie `dft_cg_enable_i` = 0 có rủi ro gì?
**Đáp:** Trong simulation không sao. Nếu sau này thêm DFT thì input này cần một nguồn thật.

### Table 11-1. Requirements on other owners

- **Để làm gì:** những gì PWM cần người khác làm, và nếu thiếu thì cái gì bị chặn.
- **Cột:** `Item` = yêu cầu; `Owner` = ai chịu trách nhiệm; `What it blocks` = hậu quả nếu không làm.
- **Chỉ vào:**
  - Bus owner: `paddr[11:0]` phải là offset trong region.
  - SCRC owner: vị trí bit `CLK_EN` và `SOFT_RST_CTRL` cho PWM.
  - Firmware owner: `SCRC` chỉ đóng clock PWM sau safe stop; nếu không, output bị đóng băng ở mức khác 0 tại power stage.
  - IO pad / IO MUX owner: chọn PIN cho `PWM_0..7`, `TIM_EXT0..3` và default sau reset.
- Dưới bảng: 5 accepted limits; việc còn mở là gate count, sau synthesis.

**Hỏi:** Vì sao firmware phải safe stop trước khi gate?
**Đáp:** Mỗi output là flip-flop, gate clock thì nó giữ mức. STOP | RST đưa cả 4 output về 0 trước.

### Table A-1. Acronyms

Giải nghĩa 4 từ viết tắt: APB, DFT, ICG, PWM.

### Table B-1. First review

Ghi các ý kiến review lần đầu và câu trả lời. Đáng chỉ vào: 4 event line không phải 4 lần hết period; 16 bit đủ vì period từ 100 ns tới 838.9 ms ở 20 MHz (MAS 7.1).

## 5. Vì sao con số này

| Con số | Ở đâu (bảng/hình) | Vì sao | Nếu khác thì sao |
|---|---|---|---|
| `20 MHz`, 1 cycle = 50 ns | MAS 7.1, Table B-1 | Chip chỉ có một tần số, không có PLL. Mọi con số thời gian bên dưới tính từ đây. | Đổi tần số thì mọi period và tần số dưới đây đổi theo đúng tỉ lệ. |
| `0x8003_4000`, 16 KiB, `APB_M13` | Figure 3-1 (khung), MAS 1 | Chọn theo HAS. Mỗi port APB được 16 KiB, xếp từ `0x8000_0000`: `0x8000_0000 + 13 × 0x4000` = `0x8003_4000`. | Phải đổi HAS, contract và driver cùng lúc. |
| 4 module × 4 channel = 16 | Figure 3-1, Table 7-2, 7-3 | Cố định trong IP: `apb_adv_timer` có 4 `timer_module`, mỗi module 4 comparator. QSOC không sửa RTL bên trong block. | Muốn khác thì phải sửa RTL vendor. |
| `TIMER_NBITS` = 16; `TH`, `CHn_TH.TH`, `COUNTER` 16 bit | Figure 3-1 ("16-bit counter"), Table 6-1 | Default của IP, QSOC giữ nguyên. 16 bit đủ cho PWM: 1000 duty steps ở 20 kHz, 20 000 ở 1 kHz. | Ít bit hơn thì mất độ phân giải và tần số thấp. 16 bit quá ít cho timebase, nên timebase là IP khác (TIMER). |
| 65 536 count, wrap 3.2768 ms, 305 Hz | Table B-1 ("Is 16 bits enough?") | `2^16` = 65 536; 65 536 × 50 ns = 3.2768 ms; 20 MHz / 65 536 ≈ 305 Hz. Đây là period dài nhất khi `PRESC` = 0. | Cần chậm hơn thì dùng `PRESC`. |
| `PRESC` 8 bit `[23:16]`, chia `PRESC + 1` = 1..256 | Table 6-1, MAS 2 | Cố định trong IP (`prescaler` có input 8 bit). `PRESC + 1` để giá trị 0 nghĩa là không chia. | Nhiều bit hơn thì chậm hơn được, nhưng phải sửa IP. |
| 838.9 ms, 1.19 Hz | MAS 7.1 | 65 536 × 256 = 16 777 216 cycle × 50 ns ≈ 838.9 ms; 1 / 0.8389 s ≈ 1.19 Hz. Period dài nhất của saw-tooth. | Không có cách chậm hơn trong một module, trừ khi đếm theo tín hiệu khác qua `IN_SEL`. |
| 100 ns, 10 MHz | MAS 7.1 | END − START = 1, `PRESC` = 0: (1 + 1) × 1 = 2 cycle = 100 ns, tức 20 MHz / 2 = 10 MHz. Hai cycle là đủ cho một mức 1 và một mức 0. | Tần số cao hơn thì duty chỉ còn vài bước, gần như vô dụng. |
| `(END − START + 1)` và `2 × (END − START)` | MAS 7.1 | Saw-tooth đi qua END − START + 1 giá trị rồi nạp lại. Up/down đi lên END − START bước rồi xuống END − START bước, nên nhân 2. | Cùng `TH` thì centre-aligned có period khoảng gấp đôi. |
| `CFG` reset = `0x1000` | Table 6-1 | Chỉ `SAW` (bit 12) reset 1, các field khác 0: `1 << 12` = `0x1000`. Mặc định là saw-tooth, trường hợp QSOC dùng và verify. | `SAW` = 0 thì là up/down, period tính theo công thức × 2. |
| `TH`: START `[15:0]`, END `[31:16]` | Table 6-1 | Hai giá trị 16 bit ghép vào một register 32 bit. Cố định trong IP. | — |
| `CHn_TH.MODE` 3 bit `[18:16]`, 7 action, 7 = hold | Table 6-1, Table 7-1 | 7 action cần 3 bit (`2^3` = 8 mã). Mã 7 không có action trong comparator, nên output giữ nguyên. | Cố định trong IP. |
| `CHn_LUT`: LUT `[15:0]`, FLT `[17:16]` | Table 6-1 | Field của `lut_4x4` và `out_filter`, hai module không được instantiate. Chỉ lưu và đọc lại. | Ghi gì cũng không đổi output. |
| `CMD` 5 bit; `0x01` START, `0x0A` safe stop | Table 6-1, MAS 7.7 | Mỗi lệnh một bit: START 0, STOP 1, UPDATE 2, RST 3, ARM 4. STOP \| RST = `0x02 \| 0x08` = `0x0A`. | Chỉ STOP thì output giữ mức; gate khi chưa RST thì output đóng băng. |
| Offset: `M` = `0x000`/`0x040`/`0x080`/`0x0C0`; `M+0x00`..`M+0x2C`; `CHn` = `+4n` | Table 6-1 | Cố định trong IP. Register index là `PADDR[9:2]`, module `i` bắt đầu ở index `0x10 × i`, tức byte `0x40 × i`. Mỗi module 12 register × 4 byte = `0x30`. | `M+0x30`..`M+0x3C` là lỗ: đọc 0, ghi bị bỏ qua. |
| `EVENT_CFG` = `0x100`, `CH_EN` = `0x104`; lỗ `0x108`..`0x3FC` | Table 6-1, MAS 7.6 | Cố định trong IP: hai register chung ở index `0x40` và `0x41`, tức byte `0x100` và `0x104`, sau 4 module (`4 × 0x40` = `0x100`). | Lỗ đọc 0, không báo lỗi. |
| `CH_EN` 4 bit `[3:0]`, 4 clock gates | Figure 3-1, Table 6-1 | Một bit cho một module; reset 0 nên cả 4 module đóng clock sau reset. | — |
| `EVENT_CFG`: SEL 4 bit × 4 `[15:0]`, EN `[19:16]`; "4 x (16 : 1)" | Figure 3-1, Table 6-1 | Chọn 1 trong 16 channel cần `log2 16` = 4 bit. 4 event line nên 4 SEL và 4 bit EN. | Cố định trong IP. |
| 4 event line, `events_o[3:0]`, `o_int_pwm` 4 bit | Figure 3-1, Table 5-1, Table 9-1 | Cố định trong IP: 4 bộ chọn trên 16 channel output. 4 nguồn trên một fast line khớp với MAS INTMAP. | Nhiều hơn 4 channel cần báo ngắt cùng lúc thì không đủ selector. |
| Fast line 7, `mcause 23` | Figure 3-1, Table 5-1, Table 9-1 | Line 7 chọn theo HAS / bảng interrupt của INTMAP. `mcause` = 16 + line = 16 + 7 = 23; RISC-V dành cause từ 16 trở lên cho platform. | Đổi line thì đổi `mcause` và vector, firmware phải đổi handler. |
| 48 input = 32 `ext_sig_i` + 16 channel | Figure 3-1 ("input pool, 48 signals"), Table 7-3 | Pool trong RTL là `{ch_3_o, ch_2_o, ch_1_o, ch_0_o, ext_sig_i}`: `EXTSIG_NUM + 16` = 32 + 16 = 48. | `EXTSIG_NUM` đổi thì pool đổi theo. |
| `EXTSIG_NUM` = 32, chỉ 4 dùng; `ext_sig_i[31:4]` = 0 | Figure 3-1, Table 7-3, Table 10-1 | 32 là default của IP. QSOC chỉ có 4 pad `TIM_EXT`, nên 28 bit còn lại tie 0, không để hở. | Giảm xuống 4 thì pool còn 20 và index channel dịch từ 32 xuống 4; Table 7-3 và firmware phải đổi. |
| `TIM_EXT0..3`, `i_tim_ext` 4 bit, `IN_SEL` 0–3 | Figure 3-1, Table 5-1, Table 7-3 | Chip có sẵn 4 pad `TIM_EXT`. Nối vào `ext_sig_i[3:0]` theo thứ tự pad để `IN_SEL` đoán được từ tên pad. | Về điện, bốn bit nào cũng chạy, nhưng phải tra bảng. |
| `IN_SEL` 8 bit `[7:0]`; 48–255 = hằng 0 | Table 6-1, Table 7-3 | Cố định trong IP (`cfg_sel_i` 8 bit). 48 tín hiệu chỉ cần 6 bit, nên mã 48–255 ra hằng 0. | Chọn nhầm mã ≥ 48 thì module chỉ đếm ở `IN_MODE` 0 và 1. |
| `32 + 4 × module + n` | Table 7-3, Table 6-1 (`EVENT_CFG` dùng `4 × module + n`) | `ext_sig_i` chiếm index 0–31, nên `ch_0_o[0]` ở 32; mỗi module 4 channel. Ví dụ `ch_1_o[2]` = 32 + 4 + 2 = 38. | — |
| `IN_MODE` 3 bit `[10:8]`, mode 0–7 | Table 6-1, Table 7-4 | 8 mode cần `log2 8` = 3 bit. Cố định trong IP (`cfg_mode_i` 3 bit). | — |
| `dft_cg_enable_i` = 0, `low_speed_clk_i` = 0 | Figure 3-1, Table 10-1 | Không có nguồn test-mode trong pad ring và không có clock chậm. | `CLK_SEL` = 1 thì module không đếm. Thêm DFT sau này thì `dft_cg_enable_i` cần nguồn thật. |
| 8 pad `PWM_0..7`, `o_pwm` 8 bit = `[3:0]` + `[7:4]` | Figure 3-1, Table 5-1, Table 7-2 | Chip có 8 pad PWM. Trong RTL `ch_i_o[3:0]` là 4 channel của module `i`, nên `ch_0_o` + `ch_1_o` = trọn module 0 và 1: hai tần số nền độc lập, mỗi tần số 4 channel. | Lấy channel 0 của cả 4 module thì được 4 tần số, nhưng mỗi tần số chỉ 1 channel. |
| `ch_2_o`, `ch_3_o` để hở | Figure 3-1 ("internal"), Table 10-1 | Module 2 và 3 không có pad; vẫn dùng được cho event và input pool. | — |
| `paddr` 12 bit, `APB_ADDR_WIDTH` = 12, bit 13:12 không dùng | Table 5-1, Table 11-1 | Default của IP, và quyết định 2026-09-24 giữ 12 bit ở wrapper. Region 16 KiB cần 14 bit offset, nhưng IP không dùng bit nào trên bit 9. | Thêm bit 13:12 cũng không đổi gì. |
| `PADDR[9:2]`, window 1 KiB, alias mỗi `0x400` | Table 5-1, MAS 7.6 | Index 8 bit × 4 byte = 256 × 4 = 1 KiB; `[1:0]` bỏ vì mọi register là word 32 bit. 16 KiB / 1 KiB = 16 bản lặp; chấp nhận vì không đáng tốn logic cho lỗi firmware không thấy. | Muốn báo lỗi thì phải thêm decode ở wrapper hoặc bus. |
| `pwdata`/`prdata` 32 bit, `pready` = 1, `pslverr` = 0 | Table 5-1 | Bus APB4 32 bit. Cố định trong IP: zero wait state, không báo lỗi. | — |
| 2FF | Figure 3-1 ("2FF sync"), Table 5-1 | `input_stage` lấy mẫu `ext_sig_i` không có synchroniser. Hai flop là synchroniser tối thiểu theo quy ước, đặt trong wrapper (quyết định 2026-09-24). | Không có 2FF thì pad bất đồng bộ có thể gây metastability trong input stage. |
| Commit `c8faec1e`, SolderPad 0.51 | Table 4-1 | Commit cố định là bản RTL mà MAS V2.1 đã đối chiếu. Licence do upstream đặt. | Đổi commit thì phải đối chiếu MAS lại với RTL. |
| V2.0, V2.1 | Revision history | Chọn theo quy ước: V2.0 là bản viết lại, V2.1 là bản sửa theo RTL. | — |
