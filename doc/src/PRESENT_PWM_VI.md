# Thuyết trình PWM — bản đọc
**Khớp tài liệu:** `QNSC_PWM_MAS` V2.1 · **Ngày:** 2026-09-24

## 1. PWM là gì

PWM (Pulse Width Modulation) là tạo một xung vuông có period cố định.
Firmware chỉnh độ rộng phần mức 1, tức duty cycle, để điều khiển công suất trung bình: độ sáng LED, tốc độ motor.
Trong QSOC, PWM là một instance của `pulp-platform/apb_adv_timer` trên `APB_M13`, tại `0x80034000`, 16 KiB.
Bên trong có 4 timer module, mỗi module 4 channel, tổng 16 channel output; 8 channel của module 0 và 1 ra pad `PWM_0..7`, và 4 event line đi vào `INTMAP` fast line 7.

## 2. Flow end-to-end

1. **SCRC mở clock, nhả reset.** `SCRC` bật bit PWM trong `CLK_EN` để mở `i_clk_peri` cho cả block, và nhả reset `i_rst_n_peri` qua `SOFT_RST_CTRL`.
   Vị trí bit của PWM trong hai register này do SCRC owner chốt (Table 11-1).
   Sau reset: `CH_EN` = 0 nên cả 4 module chưa có clock; `EVENT_CFG` = 0 nên không có event; `o_pwm` và `o_int_pwm` đều bằng 0.
2. **Ibex (firmware) ghi register qua APB.** Đường đi: Ibex → `P_BUS` → `APB_M13` → register file `adv_timer_apb_if`. Zero wait state, không bao giờ báo lỗi.
   Thứ tự cho module `i` (base `M` = `0x40 × i`):
   - `CH_EN` (`0x104`): set `CLK_EN[i]` = 1 để mở clock gate của module `i`. Phải làm trước `CMD`, vì khi gate đóng thì ghi `CMD` không có tác dụng.
   - `CFG` (`M+0x04`): `PRESC` (chia cho `PRESC + 1`), `SAW` (1 = saw-tooth đếm lên, 0 = up/down), `IN_SEL`/`IN_MODE` chọn count source. `IN_MODE` = 0 là đếm mỗi cycle. `CLK_SEL` phải để 0.
   - `TH` (`M+0x08`): START ở `[15:0]`, END ở `[31:16]`.
   - `CHn_TH` (`M+0x0C+4n`): `TH` là compare value, `MODE` là output action (Table 7-1).
   - `CMD` (`M+0x00`) = START (`0x01`): nạp START, END, SAW vào counter và chạy.
3. **Counter chạy.** Mỗi count event từ input stage và prescaler làm counter tiến một bước.
   `SAW` = 1: START → END rồi nạp lại START. `SAW` = 0: đếm lên tới END, rồi xuống tới START, rồi lại lên.
4. **Comparator lái channel.** Mỗi channel output là một flip-flop trong `comparator`.
   Match là COUNTER bằng `CHn_TH.TH` trên một count event. "Second event" là counter tới END khi `SAW` = 1, hoặc match kế tiếp khi `SAW` = 0. Output đổi theo `MODE`.
5. **Ra pad.** `o_pwm[3:0]` = `ch_0_o[3:0]`, `o_pwm[7:4]` = `ch_1_o[3:0]` → IO MUX → pad `PWM_0..7`. IO MUX chỉ thấy `o_pwm[7:0]`; gán PIN nào là việc của IO pad owner.
   Các pin này chia sẻ với GPIO, nên IO MUX phải chọn chức năng PWM. `ch_2_o`, `ch_3_o` không ra pad.
6. **Event → interrupt.** `EVENT_CFG` (`0x100`): `SELk` (4 bit) chọn channel index `4 × module + n`, `EN[k]` bật line `k`.
   Rising edge của channel được chọn → pulse đúng 1 cycle `i_clk_peri` trên `events_o[k]` = `o_int_pwm[k]` → `INTMAP` gộp 4 line vào fast line 7 → Ibex (mcause 23).
   Event không cho biết channel nào; firmware tự nhớ mình đã chọn gì. Không có status register.
7. **External input.** Pad `TIM_EXT0..3` → IO MUX → `i_tim_ext[3:0]` → synchroniser 2FF trong wrapper → `ext_sig_i[3:0]`.
   Module chọn nó bằng `IN_SEL` 0..3 và `IN_MODE`, ví dụ `IN_MODE` = 3 là đếm mỗi rising edge. Tín hiệu ngoài chỉ là count source; start và stop chỉ đến từ `CMD`.
8. **Safe stop.** Khi `CH_EN[i]` vẫn = 1, ghi `CMD` = STOP | RST = `0x0A`. Cả 4 output của module `i` về 0.
   Sau đó mới được gate clock: xoá `CH_EN[i]`, rồi `SCRC` mới đóng `CLK_EN`.
   Nếu gate khi đang chạy, output bị đóng băng ở mức hiện tại; với power stage, mức giữ đó không an toàn.

**Ví dụ tính ở 20 MHz** (module 0, channel 0, công thức period ở MAS 7.1):

- `CFG`: `SAW` = 1, `PRESC` = 0, `IN_MODE` = 0 → một count event mỗi cycle, 50 ns.
- `TH`: START = 0, END = 999. Period = (END − START + 1) × (PRESC + 1) = 1000 cycle = 50 µs → **20 kHz**.
- `CH0_TH`: `TH` = 250, `MODE` = 2 (SETRST). Output lên 1 khi COUNTER = 250, về 0 khi tới END.
  Mức 1 kéo dài khoảng 750 trên 1000 count → **duty ≈ 75%**. Muốn duty ≈ 25% thì đặt `TH` = 750.
- Đổi `PRESC` = 19: period × 20 = 1 ms → 1 kHz, duty giữ nguyên.
- Centre-aligned: `SAW` = 0, START = 0, END = 500. Period = 2 × (END − START) × (PRESC + 1) = 1000 cycle → vẫn 20 kHz.
- MAS chỉ ghi công thức period. Duty ở trên em suy ra từ Table 7-1, có thể lệch ±1 count.
- Thời điểm giá trị `TH`, `CHn_TH`, `IN_SEL`, `IN_MODE`, `PRESC` mới có hiệu lực khi đang chạy: MAS ghi **"confirm in simulation"** (mục 12, item 11).

| IP liên quan | PWM cần gì từ IP đó |
|---|---|
| `SCRC` | mở `CLK_EN` cho `i_clk_peri`, nhả reset; chỉ đóng clock sau safe stop |
| `P_BUS` (`APB_M13`) | APB4 tới block; `paddr[11:0]` là offset trong region (bus trừ base) |
| Ibex (firmware) | lập trình register; xử lý interrupt fast line 7 |
| IO MUX | nối `PWM_0..7` ra pad và `TIM_EXT0..3` vào; default out of reset còn mở |
| `INTMAP` | gộp 4 event line vào fast line 7 |

## 3. Giải thích từng hình

### Figure 3-1. PWM block: register file, clock gates, four timer modules, event multiplexer

Hình trả lời: bên trong PWM có gì, và mỗi tín hiệu vào/ra nối với ai trong chip.

| Block | Là gì | Nối với ai / tín hiệu |
|---|---|---|
| `P_BUS (APB)` | bus peripheral của chip | port `APB_M13` → register file |
| APB register file `adv_timer_apb_if` | toàn bộ register: `CMD CFG TH CHn_TH CHn_LUT COUNTER EVENT_CFG CH_EN` | `CH_EN` → clock gates; config → từng timer module; `EVENT_CFG` → event mux |
| 4 clock gates | một clock gate cho mỗi module, `en = CH_EN[i]`, `test_en = dft_cg_enable_i` | vào `i_clk_peri`; ra clock riêng cho timer module 0..3 |
| `timer_module 0` | `input_stage (IN_SEL)`, prescaler, 16-bit counter, 4 comparator | ra `ch_0_o[3:0]` |
| `timer_module 1` | giống module 0 | ra `ch_1_o[3:0]` |
| `timer_module 2 (internal)` | giống, nhưng không có pad | ra `ch_2_o[3:0]`, chỉ dùng bên trong |
| `timer_module 3 (internal)` | giống, không có pad | ra `ch_3_o[3:0]`, chỉ dùng bên trong |
| `16 ch` | bus gộp 16 channel `{ch_3_o, ch_2_o, ch_1_o, ch_0_o}` | → IO MUX (chỉ `ch_0_o`, `ch_1_o`); → event mux (16); → input pool (`ch[15:0]`) |
| event mux | 4 bộ chọn 16:1, mỗi bộ có rising edge detect | vào 16 channel và `EVENT_CFG`; ra `events_o[3:0]` |
| `INTMAP fast line 7 (mcause 23)` | interrupt map của chip | nhận `events_o[3:0]` |
| IO MUX (bên phải) | pad mux | `PWM_0..3` = `o_pwm[3:0]`, `PWM_4..7` = `o_pwm[7:4]` |
| input pool, 48 signals | nguồn cho count source | `ext_sig_i[31:0]` + `ch[15:0]` → cả 4 timer module |
| `TIM_EXT0..3` pads | 4 pad trigger ngoài | → IO MUX (dưới) → `ext_sig_i[3:0]` → input pool |
| `i_clk_peri` | clock `peri` cluster, đã qua gate `CLK_EN` của SCRC | → clock gates (và register file, event mux) |
| `i_rst_n_peri` | reset async active-low | reset cả block |
| `dft_cg_enable_i = 0` | tie-off | `test_en` của clock gates |
| `low_speed_clk_i = 0` | tie-off | `CFG.CLK_SEL` = 1 sẽ làm module không đếm |
| `ext_sig_i[31:4] = 0` | tie-off | 28 input không dùng của input pool |

Đọc mũi tên theo thứ tự:

1. Từ trên: `P_BUS` → `APB_M13` → register file. Firmware chỉ chạm block qua đường này.
2. Register file → `CH_EN` → 4 clock gates. Mỗi gate cho ra clock của một module (mũi tên thứ nhất vào mỗi module).
3. Register file → "config, per module" → timer module. Mũi tên vẽ tới module 0 nhưng nghĩa là cả 4 module, mỗi module có bộ register riêng.
4. Input pool → mũi tên thứ hai vào mỗi module: `IN_SEL` chọn 1 trong 48 tín hiệu làm count source.
5. Mỗi module xuất `ch_i_o[3:0]` sang bus `16 ch`.
6. `16 ch` → `ch_0_o`, `ch_1_o` → IO MUX → 8 pad.
7. `16 ch` → event mux; `EVENT_CFG` chọn channel và enable → `events_o[3:0]` → `INTMAP`.
8. `16 ch` → `ch[15:0]` quay lại input pool: một module có thể đếm theo output của module khác.
9. Dưới cùng: `TIM_EXT0..3` → IO MUX → `ext_sig_i[3:0]` → input pool. Bên trái: clock, reset và các tie-off.

**Hỏi:** 16 channel mà chỉ 8 ra pad, 8 cái kia để làm gì?
**Đáp:** Module 2 và 3 không có pad. Output của chúng chỉ vào event mux và input pool. Vì vậy pad có hai period độc lập, mỗi period 4 channel.

**Hỏi:** Synchroniser 2FF của `TIM_EXT` nằm đâu trong hình?
**Đáp:** Ô `2FF sync` ở góc dưới, giữa IO MUX và input pool: hai flip-flop trong wrapper đồng bộ `i_tim_ext` về `i_clk_peri` rồi mới thành `ext_sig_i[3:0]` (Table 5-1).

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
