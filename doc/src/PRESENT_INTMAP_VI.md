# Thuyết trình INTMAP — bản đọc

**Khớp tài liệu:** `QNSC_Interrupt_Map_MAS` V2.1 · **Ngày:** 2026-09-24

## 1. INTMAP là gì

INTMAP (module `m_qnsc_intmap`, thư mục `design/intmap`) là một khối combinational.
Nó nối 27 nguồn interrupt từ 8 loại khối peripheral vào 12 chân interrupt của Ibex.
26 nguồn maskable chia thành 11 source group; mỗi group lái đúng một fast line
`irq_fast_i[n]`, qua cổng OR nếu group có nhiều nguồn, qua wire nếu chỉ có một.
Watchdog bark đi bằng một wire riêng vào `irq_nm_i`; khối không có clock, reset,
flip-flop, thanh ghi hay cổng bus.

## 2. Flow end-to-end

**Ví dụ chính: UART0 nhận một byte (line 4, level).**

1. **Peripheral — UART0.** Một byte vào RX. UART0 là 16550: `IIR` ghi nguyên nhân,
   chân `INT` lên 1. `INT` là level, nó giữ 1 cho tới khi firmware xử lý xong.
2. **INTMAP — port vào.** `INT` nối vào `i_int_uart_0`, rộng 1 bit.
3. **INTMAP — wire.** Group UART0 chỉ có một nguồn, nên `o_int_fast[4] = i_int_uart_0`.
   Không flip-flop, không cycle delay.
4. **Ibex — chân và CSR.** `o_int_fast[4]` nối `irq_fast_i[4]`. Trong Ibex `mip` là
   combinational (`assign mip.irq_fast = irq_fast_i`), nên bit `mip` 20 lên ngay.
   Core chỉ nhận khi bit `mie` 20 = 1 và `mstatus.MIE` = 1. Nhiều line cùng pending
   thì Ibex chọn index nhỏ nhất.
5. **Ibex — trap.** `mcause` = 16 + 4 = 20. `mtvec` luôn ở vectored mode, nên core nhảy
   tới `mtvec + 4·20 = mtvec + 0x50`. Vào trap thì `mstatus.MIE` bị clear.
6. **Handler.** Code ở `mtvec + 0x50` đã là handler của UART0. Không đọc claim register,
   không có bus transaction nào trên đường interrupt. Handler đọc `IIR` để biết nguyên
   nhân, rồi đọc thanh ghi 16550 mà `IIR` chỉ ra — với RX là đọc dữ liệu nhận.
7. **Line rơi.** Hết nguyên nhân thì UART0 hạ `INT`, wire hạ `o_int_fast[4]`, `mip` 20
   về 0. Handler chạy `mret`, `mstatus.MIE` bật lại.

**Đường NMI — WDT bark (level).**

1. WDT (`aon_timer`) tới ngưỡng bark, `nmi_wdog_timer_bark_o` lên 1 và giữ.
2. Vào `i_int_wdt_bark`, wire thẳng tới `o_int_nm`. Không OR với nguồn nào; không fast
   line nào phụ thuộc bark.
3. `o_int_nm` nối `irq_nm_i`. Chân này không bị `mie` hay `mstatus.MIE` mask, và thắng
   mọi fast line.
4. `mcause` = 31, vector `mtvec + 0x7C`.
5. Handler clear bằng W1C `INTR_STATE` của WDT, line rơi.
6. Trong Debug Mode, Ibex bỏ qua `irq_nm_i`. Vì bark là level giữ nguyên, nó trap ngay
   sau khi core resume.

**Line dùng chung — GPIO0-3 (line 9, pulse).**

- 4 instance GPIO, mỗi cái một chân `interrupt`, vào `i_int_gpio[3:0]`. OR 4 bit thành
  `o_int_fast[9]`, `mcause` 25, vector `mtvec + 0x64`.
- `mcause` chỉ nói "group GPIO". Muốn biết instance nào, pin nào, handler đọc
  `INTSTATUS` của từng instance.
- `INTSTATUS` là read-to-clear: mỗi instance đọc đúng một lần, xử lý hết mọi bit thấy
  được. Đọc lần hai sẽ ra 0.
- GPIO là pulse, nên lúc vào handler line có thể đã về 0. Handler phải chịu được việc
  đọc thấy toàn 0.

**Nguồn pulse — PWM (line 7) và TIMER.**

- `events_o[n]` của PWM là pulse. 4 bit OR thành `o_int_fast[7]`, `mcause` 23.
- INTMAP không latch, `mip` cũng không latch. Pulse đến lúc `mstatus.MIE` = 0 (đang trong
  handler khác), lúc bit `mie` 23 = 0, hoặc lúc Debug Mode, thì không có trap.
- Cái giá: interrupt đó mất. PWM không giữ record nào; chỉ period sau mới bắn lại. Vì
  vậy không dùng PWM event làm thông báo một lần.
- TIMER chạy periodic cũng vậy: mất, period sau bắn lại. TIMER one-shot có prescaler hoặc
  ref clock thì ra level, giữ tới khi ghi `TIMER_RESET_LO`/`_HI`.
- GPIO khác: pulse mất nhưng pin vẫn nằm trong `INTSTATUS`.

**IP liên quan và yêu cầu hai chiều**

| IP liên quan | INTMAP cần gì / IP đó cần gì |
|---|---|
| 8 loại peripheral | INTMAP cần đúng port và width như Table 7-1; nguồn level phải giữ tới khi clear. Peripheral không cần gì từ INTMAP: không ack, không thanh ghi |
| WDT | INTMAP cần bark là level giữ. WDT cần bark không bị mask, nên nó có wire riêng tới `irq_nm_i` |
| Ibex | INTMAP dùng `irq_fast_i[10:0]` và `irq_nm_i`. Ibex lo priority, mask (`mie`, `mstatus.MIE`) và vector |
| `design/top` | Instantiate INTMAP, và tie `irq_fast_i[14:11]`, `irq_external_i`, `irq_timer_i`, `irq_software_i` về 0 |
| Firmware | Vector table ở `mtvec + 0x40` tới `+0x68` và `+0x7C`; `mtvec` 256-byte aligned; cài handler trước khi set `mstatus.MIE`; clear interrupt của peripheral trước khi đóng clock gate |
| SCRC | Không cần thay đổi; luật clock gate nằm ở firmware |

## 3. Giải thích từng hình

### Figure 3-1. INTMAP: 5 OR gates and 6 wires onto irq_fast_i[10:0], one wire onto irq_nm_i

**Hình trả lời:** mỗi nguồn interrupt đi vào đâu, qua OR hay wire, và mỗi chân interrupt
của Ibex do ai lái.

**Đọc từ trái sang phải:**

1. **Sources (cột trái).** 12 hộp. Mỗi hộp ghi tên khối, tên port gốc, và shape (level,
   pulse, hoặc pulse/level cho TIMER). WDT có hai hộp: wake-up và bark.
2. **INTMAP ports (hộp nét đứt giữa).** Mỗi hộp là một port `i_int_*` kèm width. Dòng dưới
   ghi `OR` nếu port nhiều bit, `wire` nếu 1 bit.
3. **Output wires (nhãn giữa).** `o_int_fast[0]` tới `o_int_fast[10]`, và `o_int_nm`.
4. **Ibex pins (khung phải).** Chân `irq_fast_i[n]` kèm `mcause`, và `irq_nm_i mcause 31`.
5. **Tie-offs (hộp nét đứt `design/top`).** Hằng `4'b0` vào `irq_fast_i[14:11]`, ba số 0
   vào `irq_external_i`, `irq_timer_i`, `irq_software_i`. Các đường này không đi qua INTMAP.

**Các loại hộp**

| Kiểu hộp | Ý nghĩa |
|---|---|
| Hộp viền mảnh, cột trái | Source: khối, port gốc, shape |
| Hộp trong INTMAP, ghi `OR` | Port nhiều bit, OR reduction thành 1 line (5 hộp) |
| Hộp trong INTMAP, ghi `wire` | Port 1 bit, nối thẳng (6 fast line + NMI) |
| Hộp viền đậm | Đường NMI: WDT bark → `i_int_wdt_bark` → `o_int_nm` → `irq_nm_i` |
| Khung nét đứt "INTMAP" | Biên của `m_qnsc_intmap` |
| Khung nét đứt "design/top" | Tie-off hằng số ở top, không thuộc INTMAP |
| Hộp trong khung "Ibex" | Chân input của Ibex, kèm `mcause` |

**Đi một line OR — SPI device, line 1.** 8 port `intr_*_o`, đều level, vào
`i_int_spi_device[7:0]`. OR 8 bit ra `o_int_fast[1]`, tới `irq_fast_i[1]`, `mcause` 17,
vector `mtvec + 0x44`. Chỉ cần 1 trong 8 lên là line lên. Line chỉ rơi khi cả 8 đã clear
bằng W1C `INTR_STATE`. Đây cũng là OR sâu nhất, path dài nhất của khối.

**Đi một line wire — I2C, line 3.** `interrupt_o`, level, vào `i_int_i2c`, nối thẳng ra
`o_int_fast[3]`, tới `irq_fast_i[3]`, `mcause` 19, vector `mtvec + 0x4C`. Handler clear
bằng `IACK`, bit 0 của `CMD`.

**Hỏi:** `mcause` ghi trên hình, vậy INTMAP tạo ra `mcause` à?
**Đáp:** Không. Ibex tự sinh `mcause` = 16 + index của line. Hình ghi ra để thấy chân nào
ứng với `mcause` nào.

**Hỏi:** Sao bark không OR vào một fast line?
**Đáp:** Fast line bị mask bởi `mie` và `mstatus.MIE`. Watchdog phải vào được cả khi
firmware treo với interrupt đang tắt, nên nó đi `irq_nm_i`, không mask được.

**Hỏi:** Hộp `design/top` là gì, sao không nằm trong INTMAP?
**Đáp:** Là hằng 0 cho các chân Ibex không dùng. QSOC không có PLIC hay CLINT, và 4 fast
line còn dư. Để tie-off ở top thì INTMAP chỉ có đúng 27 input bit và 12 output bit.

**Hỏi:** Hai line lên cùng lúc thì sao?
**Đáp:** Ibex lấy index nhỏ nhất trước, nên thứ tự line chính là priority. NMI thắng tất
cả fast line. Đổi thứ tự là phải re-synthesis.

## 4. Giải thích từng bảng

### Revision history (bảng không đánh số)

Ghi các phiên bản: V2.0 viết lại chỉ còn spec, V2.1 nói rõ NMI là wire qua khối, thêm
source port, width, shape của timer, và vẽ lại hình. Lý do nằm ở `_DECISIONS`.

### Table 4-1. Upstream IP used

**Để làm gì:** liệt kê IP bên ngoài mà khối dùng. **Cột:** From, Module, Commit, Licence.
Mọi ô là `--`: khối tự thiết kế, chỉ gồm các lệnh `assign`, không instantiate gì.

**Hỏi:** Không dùng IP nào, sao vẫn để bảng?
**Đáp:** Để khẳng định rõ là không có dependency bên thứ ba nào, không phải bỏ sót.

### Table 5-1. Interrupt map interface

**Để làm gì:** liệt kê mọi port của khối.

**Cột:**
- **Signal:** tên port, theo `QNSC_RTL_Design_Naming_Rule` V1.0 mục 3.6.
- **Dir:** in hay out.
- **Width:** số bit.
- **Description:** port nối với ai; với port nhiều bit, bit nào là nguồn nào.

**Dòng đáng chỉ:**
- `i_int_spi_device`, 8 bit: lớn nhất, bit theo thứ tự khai báo port.
- `i_int_timer_1`, 2 bit: bit 0 `irq_lo_o`, bit 1 `irq_hi_o`. So với `i_int_timer_0`
  chỉ 1 bit, vì TIMER0 chạy 64-bit mode.
- `i_int_wdt_wakeup` và `i_int_wdt_bark`: cùng một WDT, hai port riêng.
- `o_int_fast` 11 bit và `o_int_nm` 1 bit: toàn bộ output.
- Tổng: 27 input bit, 12 output bit. Không có `i_clk_*`, không có `i_rst_n_*`.

**Hỏi:** Sao TIMER0 chỉ 1 bit mà TIMER1 có 2?
**Đáp:** TIMER0 chạy 64-bit mode, chỉ lái `irq_lo_o`; `irq_hi_o` luôn 0.

**Hỏi:** Không clock, không reset thì khối có an toàn không?
**Đáp:** Có, vì không có state nào cần reset. Output chỉ là hàm của input.

### Table 7-1. Interrupt line assignment

**Để làm gì:** là hợp đồng giữa hardware và firmware: line nào, nguồn nào, `mcause` nào,
vector ở đâu. Bảng sinh từ `util/qsoc_contract.yml`.

**Cột:**
- **Line:** index *n* của fast line; cũng là priority, nhỏ thắng.
- **CPU port:** chân Ibex, `irq_fast_i[n]` hoặc `irq_nm_i`.
- **mcause:** 16 + *n*; bằng số bit `mie` bật line đó.
- **Vector:** `mtvec + 4·mcause`, chỗ core nhảy tới.
- **INTMAP input:** port của khối.
- **Source port:** tên port gốc trong RTL của peripheral.
- **Width:** số nguồn trong group.
- **Shape:** level hay pulse.

**Dòng đáng chỉ:**
- Line 0, DMA: priority cao nhất trong các fast line.
- Line 1, SPI device: 8 nguồn trên một line.
- Line 6 và 10, TIMER: "pulse; level in one-shot with prescaler or ref clock".
- Line 7 và 9, PWM và GPIO: pulse.
- Line 11-14: tied 0 ở `design/top`, `mcause` 27-30 không bao giờ xảy ra.
- Dòng cuối, `irq_nm_i`: `mcause` 31, vector `mtvec + 0x7C`, nguồn là bark.

**Hỏi:** Sao DMA đứng line 0?
**Đáp:** Thứ tự theo luật "mất dữ liệu trước, thời gian người sau". DMA đứng đầu vì cả hệ
thống đang chờ transfer xong.

**Hỏi:** Tính vector thế nào?
**Đáp:** Line 4 thì `mcause` 20, vector = `mtvec + 4·20` = `mtvec + 0x50`. Bark là
`4·31 = 0x7C`.

**Hỏi:** Sao Width của line 11-14 là 0?
**Đáp:** Cột Width đếm số nguồn trong group. Line spare không có nguồn nào.

### Table 7-2. Interrupt source totals

**Để làm gì:** tóm tắt các con số, cũng sinh từ contract. **Cột:** tên đại lượng và
Count.

**Dòng đáng chỉ:** 26 nguồn fast + 1 NMI = 27. 8 source block tính theo loại (DMA, SPI,
I2C, UART, TIMER, PWM, WDT, GPIO). 11 nguồn pulse = TIMER1 2 + PWM 4 + GPIO 4 + TIMER0 1.
11 line dùng trên 15 Ibex có, dư 4.

**Hỏi:** 8 block nhưng hình có 12 hộp nguồn?
**Đáp:** Đếm theo loại khối. SPI device và SPI host tính chung là SPI; UART0/1, TIMER0/1,
GPIO0-3 cũng vậy; WDT có 2 hộp.

**Hỏi:** NMI có được tính không?
**Đáp:** Có, nó là 1 trong 27.

### Table 7-3. How each source is cleared, and what a missed pulse costs

**Để làm gì:** cho firmware biết clear từng nguồn thế nào, và nếu lỡ một pulse thì mất gì.

**Cột:**
- **Source:** nguồn.
- **Shape:** level hay pulse.
- **Cleared by:** thao tác làm line rơi.
- **A missed pulse:** hậu quả khi pulse đến lúc bị mask; `--` nghĩa là nguồn level, không
  thể lỡ.

**Dòng đáng chỉ:**
- DMA, SPI, WDT: W1C `DMA_ISR` hoặc `INTR_STATE`.
- I2C: `IACK`, bit 0 của `CMD`. UART: đọc thanh ghi 16550 mà `IIR` chỉ ra.
- GPIO: không cần clear line; `INTSTATUS` clear khi đọc. Pulse mất nhưng pin vẫn được ghi.
- TIMER, PWM: pulse mất, period sau bắn lại.

**Hỏi:** Vì sao pulse có thể mất?
**Đáp:** INTMAP không latch, và `mip` của Ibex là combinational. Pulse kết thúc lúc
`mstatus.MIE` hoặc bit `mie` đang clear, hoặc lúc Debug Mode, thì không trap.

**Hỏi:** Sao không thêm latch pending vào INTMAP?
**Đáp:** Không cần: mọi nguồn level tự giữ line, còn pulse thì hoặc được ghi (GPIO) hoặc
lặp lại (TIMER, PWM).

### Table 9-1. Functions this block does not provide

**Để làm gì:** chỉ ra các chức năng của một interrupt controller thông thường nằm ở đâu,
vì INTMAP không có. **Cột:** Function và Where it lives.

**Dòng đáng chỉ:**
- **Which group fired:** `mcause`, qua địa chỉ vectored. Không cần claim register.
- **Priority resolution:** Ibex, theo index.
- **Per-line enable:** `mie` bit 16-26 trong core.
- **Acknowledge:** clear ở chính nguồn; không có ack nào gửi tới INTMAP.

**Hỏi:** Không có PLIC thì mask một line bằng cách nào?
**Đáp:** Clear bit `mie` tương ứng, 16 + *n*, trong Ibex.

### Table 10-1. Every interrupt input on the core

**Để làm gì:** chứng minh mọi chân interrupt của Ibex đều có người lái, không chân nào
thả nổi. Bảng sinh từ contract.

**Cột:**
- **Core input:** chân Ibex.
- **Width:** số bit của chân.
- **Driven by:** INTMAP hay tie-off ở `design/top`.
- **Note:** `mcause` liên quan, hoặc lý do tie 0.

**Dòng đáng chỉ:**
- `irq_fast_i[10:0]` và `irq_nm_i`: do INTMAP lái.
- `irq_fast_i[14:11]`: `4'b0`, spare.
- `irq_external_i`: 0 vì không có PLIC, `mcause` 11 không xảy ra.
- `irq_timer_i`, `irq_software_i`: 0 vì không có CLINT; `mip.MTIP`, `mip.MSIP` luôn 0.

**Hỏi:** Không dùng `irq_timer_i` thì tick cho RTOS ở đâu?
**Đáp:** TIMER0 là một fast line bình thường, `mcause` 26. RTOS port sang QSOC phải tự có
timer driver.

**Hỏi:** Sao tie-off ở top chứ không trong INTMAP?
**Đáp:** INTMAP chỉ giữ các đường có nguồn thật. Tie-off là chuyện nối dây của top.

### Table 11-1. Requirements on other owners

**Để làm gì:** những gì người khác phải làm thì thiết kế mới chạy đúng.

**Cột:**
- **Item:** yêu cầu.
- **Owner:** ai làm.
- **What it blocks:** chưa làm thì hỏng cái gì.

**Dòng đáng chỉ:**
- Vector table ở `mtvec + 0x40` tới `+0x68` và `+0x7C`; `mtvec` 256-byte aligned vì Ibex
  bỏ qua `mtvec[7:0]`.
- Cài handler trước khi set `mstatus.MIE`.
- Clear interrupt của peripheral trước khi đóng `CLK_EN`; `SCRC` không cần đổi.
- HAS dòng 69 và 155 phải sửa: bark đi qua INTMAP, nên INTMAP nhận 27 nguồn, không phải 26.

**Hỏi:** Gate clock một peripheral đang giữ interrupt thì sao?
**Đáp:** Clock dừng thì flip-flop giữ state, nên line vẫn cao. Muốn clear phải ghi thanh
ghi của peripheral đó, mà nó đang bị gate nên không ghi được. Core cứ vào lại handler đó
chừng nào bit `mie` còn set.

**Hỏi:** Sao là luật firmware mà không bắt SCRC từ chối gate?
**Đáp:** Đơn giản nhất và không cần thêm RTL trong `SCRC`.

### Table A-1. Acronyms

Bảng giải nghĩa từ viết tắt. Đáng chỉ: PLIC và CLINT đều ghi "Not present in QSOC"; WDT
là `aon_timer`; SCRC là System Clock Reset Control.

### Table B-1. First review

**Để làm gì:** ghi các câu hỏi review và câu trả lời. **Cột:** Item, Reviewer, Response.

**Dòng đáng chỉ:**
- GPIO: một line cho 4 instance (Day005); pin nào fire thì xem `INTSTATUS`.
- DMA là level, giữ bởi W1C `DMA_ISR`.
- Không cần latch pending trong INTMAP.
- NMI có trong tổng 27 và trong Table 10-1 (câu hỏi của thầy, 2026-09-23).
- Line của peripheral bị gate vẫn giữ mức cao.

**Hỏi:** Câu thầy hỏi hôm 23/09 đã xử lý ở đâu?
**Đáp:** Bark được đếm trong 27 ở Table 7-2, và có dòng `irq_nm_i` trong Table 10-1.
