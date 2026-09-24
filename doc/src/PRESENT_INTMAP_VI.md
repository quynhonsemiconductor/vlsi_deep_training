# Thuyết trình INTMAP — bản đọc

**Khớp tài liệu:** `QNSC_Interrupt_Map_MAS` V2.2 · **Ngày:** 2026-09-24

## 1. INTMAP là gì

INTMAP (module `m_qnsc_intmap`, thư mục `design/intmap`) là một khối combinational.
Nó nối 26 nguồn interrupt từ 8 loại khối peripheral vào 12 chân interrupt của Ibex.
25 nguồn maskable chia thành 11 source group; mỗi group lái đúng một fast line
`irq_fast_i[n]`, qua cổng OR nếu group có nhiều nguồn, qua wire nếu chỉ có một.
Watchdog bark đi bằng một wire riêng vào `irq_nm_i`; khối không có clock, reset,
flip-flop, thanh ghi hay cổng bus.

## 2. Flow end-to-end

### Câu chuyện chính: UART0 nhận một byte (line 4, level)

**Bước 1 — Byte tới UART0.** *Ở đâu:* UART0, một khối 16550. *Làm gì:* byte vào RX,
`IIR` ghi nguyên nhân "có dữ liệu nhận", chân `INT` lên 1. `INT` là level: giữ 1 cho tới
khi firmware xử lý. *Đi tiếp:* `INT` ra khỏi UART0, vào `i_int_uart_0` của INTMAP.
*Phụ thuộc:* interrupt RX đã được bật trong UART0; clock của UART0 đang chạy (`CLK_EN`
của `SCRC` mở).
*(Vì sao: INTMAP không có thanh ghi, nên enable trong UART0 là nơi duy nhất tắt riêng một nguồn. Ibex không latch gì, nên nguồn phải tự giữ level cho tới khi handler clear.)*

**Bước 2 — INTMAP chuyển tiếp.** *Ở đâu:* INTMAP. *Làm gì:* `i_int_uart_0` là một dây
thẳng, không OR, không flop. *Đi tiếp:* ra `o_int_fast[4]`, vào `irq_fast_i[4]` của Ibex.
*Phụ thuộc:* không có; INTMAP không có clock, reset hay register.
*(Vì sao: Ibex có 15 fast line mà QSOC chỉ cần 11, nên không cần controller; một wire hay OR là nhanh nhất và nhỏ nhất, 0 flip-flop, không bus. Bản PLIC trước tốn 258 flip-flop, một port AXI, và mỗi interrupt một claim read làm core chờ.)*

**Bước 3 — Pending trong Ibex.** *Ở đâu:* Ibex, CSR `mip`. *Làm gì:* `mip` là
combinational (`assign mip.irq_fast = irq_fast_i`), nên bit `mip` 20 lên ngay, cùng
cycle. *Đi tiếp:* sang logic chọn interrupt của core. *Phụ thuộc:* không có; `mip`
không latch gì.
*(Vì sao: Ibex để `mip` là dây từ chân để interrupt đánh thức được core khi đang WFI. Cái giá là core không giữ pending, xem câu chuyện PWM.)*

**Bước 4 — Ibex quyết định nhận.** *Ở đâu:* Ibex. *Làm gì:* core so pending với mask và
chọn một line. *Đi tiếp:* sang trap. *Phụ thuộc:* bit `mie` 20 = 1; `mstatus.MIE` = 1;
core không ở Debug Mode; không có NMI và không có line index nhỏ hơn đang pending, vì
Ibex lấy index nhỏ nhất trước.
*(Vì sao: thứ tự line theo luật "mất dữ liệu trước, thời gian người sau": lỡ event SPI hay UART là mất byte, lỡ tick timer thì period sau có lại; DMA đứng line 0 vì cả hệ thống chờ transfer xong. Đổi lại, priority cố định, đổi là phải re-synthesis.)*

**Bước 5 — Trap và nhảy vector.** *Ở đâu:* Ibex. *Làm gì:* ghi `mcause` = 16 + 4 = 20,
clear `mstatus.MIE`. `mtvec` luôn ở vectored mode. *Đi tiếp:* PC nhảy tới
`mtvec + 4·20 = mtvec + 0x50`, tức handler UART0. *Phụ thuộc:* `mtvec` 256-byte aligned,
vì Ibex bỏ qua `mtvec[7:0]`; entry ở `mtvec + 0x50` đã được cài trước khi set
`mstatus.MIE`.
*(Vì sao: `mcause` = 16 + n tự nói group nào, nên core nhảy thẳng vào đúng handler, không cần claim register như PLIC. `mtvec` phải 256-byte aligned vì Ibex bỏ qua `mtvec[7:0]`; handler phải cài trước vì INTMAP trong suốt từ reset, mọi nguồn sống ngay.)*

**Bước 6 — Handler tìm nguyên nhân.** *Ở đâu:* handler UART0, chạy trên Ibex. *Làm gì:*
không cần hỏi "ai gọi", vì vector đã nói là UART0; không đọc claim register nào. Handler
đọc `IIR`, rồi đọc thanh ghi 16550 mà `IIR` chỉ ra, ở đây là dữ liệu nhận. *Đi tiếp:*
các lần đọc đi qua bus tới thanh ghi của UART0. *Phụ thuộc:* clock UART0 vẫn chạy, nếu
không lần đọc không hoàn thành.
*(Vì sao: mỗi line chỉ mang một group, nên handler không bao giờ phải hỏi khối nào gọi; mỗi peripheral đã tự ghi event nào trong status register của nó. Nếu OR hết vào `irq_external_i` thì handler phải poll tới 14 thanh ghi mới tìm ra nguồn.)*

**Bước 7 — Line rơi.** *Ở đâu:* UART0, rồi INTMAP, rồi Ibex. *Làm gì:* hết nguyên nhân
thì UART0 hạ `INT`. *Đi tiếp:* `i_int_uart_0` → `o_int_fast[4]` → `irq_fast_i[4]`, bit
`mip` 20 về 0, không trễ cycle nào. *Phụ thuộc:* handler đã đọc đúng thanh ghi mà `IIR`
chỉ ra.
*(Vì sao: INTMAP không giữ gì, nên không có ack nào phải gửi cho nó. Clear ở peripheral là ack duy nhất trong hệ thống, và thiết kế nào firmware cũng phải làm bước này.)*

**Bước 8 — Quay về.** *Ở đâu:* Ibex. *Làm gì:* handler chạy `mret`, `mstatus.MIE` bật
lại. *Đi tiếp:* về đúng lệnh bị ngắt. *Phụ thuộc:* line đã thấp; nếu `INT` còn cao thì
core trap lại vào handler UART0 ngay.
*(Vì sao: nguồn level ở đây là kiểu status, chỉ hạ khi điều kiện hết. Còn sót một event là line vẫn cao, và core vào lại handler ngay khi `mret`.)*

**Kết thúc:** byte đã được đọc, `INT` thấp, `irq_fast_i[4]` thấp, core chạy tiếp chương
trình cũ. Trên cả đường đi không có flop nào trong INTMAP và không có bus transaction nào
cho tới khi handler đọc UART0.

### Câu chuyện NMI: watchdog bark (level)

**Bước 1 — WDT bark.** *Ở đâu:* WDT (`aon_timer`). *Làm gì:* bộ đếm watchdog tới ngưỡng
bark, `nmi_wdog_timer_bark_o` lên 1 và giữ. *Đi tiếp:* vào `i_int_wdt_bark` của INTMAP.
*Phụ thuộc:* firmware đã bật watchdog, và đã cài entry NMI ở `mtvec + 0x7C` trước khi bật.
*(Vì sao: NMI không bị `mstatus.MIE` chặn, nên luật "cài handler trước khi set `mstatus.MIE`" ở bước 5 của UART không che được nó.)*

**Bước 2 — INTMAP chuyển tiếp.** *Ở đâu:* INTMAP. *Làm gì:* một dây thẳng, không OR với
nguồn nào; không fast line nào phụ thuộc bark. *Đi tiếp:* ra `o_int_nm`, vào `irq_nm_i`.
*Phụ thuộc:* không có.
*(Vì sao: bark phải tới được cả khi firmware treo với interrupt đang tắt. OR vào một fast line thì nó bị `mie` và `mstatus.MIE` chặn đúng lúc cần nó nhất.)*

**Bước 3 — Ibex nhận NMI.** *Ở đâu:* Ibex. *Làm gì:* nhận ngay, thắng mọi fast line.
*Đi tiếp:* trap, `mcause` = 31, nhảy `mtvec + 0x7C`. *Phụ thuộc:* không cần `mie` hay
`mstatus.MIE`; chỉ cần core không ở Debug Mode. Nếu đang Debug Mode thì bark vẫn giữ
mức, core trap ngay sau khi resume.
*(Vì sao: bark không cần latch, vì `aon_timer` tự giữ nó ở level; nhờ vậy nó vẫn trap sau khi core rời Debug Mode.)*

**Bước 4 — Handler clear.** *Ở đâu:* handler NMI, rồi WDT. *Làm gì:* ghi W1C
`INTR_STATE` của WDT. *Đi tiếp:* bark hạ, `o_int_nm` và `irq_nm_i` về 0; handler `mret`.
*Phụ thuộc:* clock WDT đang chạy.
*(Vì sao: clear nằm ở nguồn (bước 7 của UART), nên nguồn phải còn clock. Vì thế luật là firmware clear trước khi đóng `CLK_EN`, thay vì bắt `SCRC` từ chối gate: đơn giản nhất và không cần thêm RTL trong `SCRC`.)*

**Kết thúc:** bark đã clear, `irq_nm_i` thấp, core về chương trình cũ, kể cả khi lúc đó
firmware đang tắt interrupt.

### Câu chuyện line dùng chung: GPIO0-2 (line 9, pulse)

**Bước 1 — Pin đổi trạng thái.** *Ở đâu:* một instance GPIO, ví dụ GPIO2. *Làm gì:* ghi
pin vào `INTSTATUS` của nó, và phát `interrupt` là một pulse. *Đi tiếp:* vào bit 2 của
`i_int_gpio[2:0]`. *Phụ thuộc:* interrupt của pin đã được bật trong GPIO2.
*(Vì sao: GPIO phát pulse nhưng `INTSTATUS` đã ghi pin, nên lỡ interrupt không mất thông tin.)*

**Bước 2 — INTMAP OR.** *Ở đâu:* INTMAP. *Làm gì:* OR 3 bit, bất kỳ instance nào lên là
line lên. *Đi tiếp:* ra `o_int_fast[9]`, vào `irq_fast_i[9]`. *Phụ thuộc:* không có.
*(Vì sao: review Day005 chốt GPIO chỉ cần một interrupt. Tách 3 line thì dùng 13 line, chỉ còn 2 spare, cái được chỉ là bớt 2 lần đọc thanh ghi.)*

**Bước 3 — Ibex nhận.** *Ở đâu:* Ibex. *Làm gì:* trap, `mcause` = 25, nhảy
`mtvec + 0x64`. *Đi tiếp:* vào handler GPIO. *Phụ thuộc:* bit `mie` 25 = 1 và
`mstatus.MIE` = 1 ngay trong lúc có pulse. Lỡ pulse thì không trap, nhưng pin vẫn nằm
trong `INTSTATUS`.

**Bước 4 — Tìm nguồn.** *Ở đâu:* handler GPIO. *Làm gì:* `mcause` chỉ nói "group GPIO".
Handler đọc `INTSTATUS` của GPIO0, 1, 2, mỗi cái đúng một lần, và xử lý mọi bit thấy
được. *Đi tiếp:* `mret`. *Phụ thuộc:* `INTSTATUS` là read-to-clear, đọc lần hai ra 0;
handler phải chịu được việc đọc thấy toàn 0.
*(Vì sao: một lần đọc `INTSTATUS` xoá mọi bit của instance đó cùng lúc. Và vì là pulse, line có thể đã về 0 trước khi handler chạy, nên có lần vào mà không thấy gì.)*

**Kết thúc:** mọi pin đã ghi đều được xử lý, `INTSTATUS` sạch. Line đã về 0 từ lúc pulse
hết, không cần clear gì ở line.

### Câu chuyện nguồn pulse: PWM (line 7)

**Bước 1 — PWM event.** *Ở đâu:* PWM. *Làm gì:* `events_o[n]` phát một pulse. PWM không
giữ record nào của event. *Đi tiếp:* vào `i_int_pwm[3:0]`, OR ra `o_int_fast[7]`, vào
`irq_fast_i[7]`. *Phụ thuộc:* không có ở INTMAP.
*(Vì sao: `apb_adv_timer` có `status_o` nhưng không nối vào thanh ghi đọc được, nên PWM phục hồi chỉ nhờ event lặp lại theo chu kỳ.)*

**Bước 2 — Ibex có kịp thấy không.** *Ở đâu:* Ibex. *Làm gì:* nếu kịp thì trap,
`mcause` = 23, nhảy `mtvec + 0x5C`. *Đi tiếp:* handler PWM, không có gì để clear.
*Phụ thuộc:* bit `mie` 23 = 1, `mstatus.MIE` = 1, không ở Debug Mode, ngay trong lúc có
pulse. `mstatus.MIE` luôn = 0 khi đang ở trong một handler khác.
*(Vì sao: core tự clear `mstatus.MIE` khi vào trap, nên lúc đang chạy handler khác là lúc dễ lỡ pulse nhất.)*

**Bước 3 — Nếu lỡ.** *Ở đâu:* không nơi nào giữ lại. *Làm gì:* INTMAP không latch, `mip`
cũng không latch, nên interrupt đó mất. *Đi tiếp:* period sau PWM bắn lại. *Phụ thuộc:*
PWM đang chạy theo chu kỳ. PWM không có event status, nên handler cũng không đọc được
event nào đã fire.
*(Vì sao chấp nhận: thêm pending latch là quay về controller có state, bản latched trước cần 52 flip-flop và một port APB; ở QSOC mọi nguồn level tự giữ, GPIO có record, TIMER và PWM periodic thì lặp lại. Vì vậy không dùng PWM event làm thông báo một lần.)*

**Kết thúc:** hoặc handler chạy, hoặc chờ tới period sau. TIMER periodic cũng vậy. TIMER
one-shot có prescaler hoặc ref clock thì ra level, giữ tới các lần ghi trong
`QNSC_TIMER_MAS` 7.5; one-shot còn lại ra pulse, và lỡ là mất hẳn, không lặp lại.

### IP liên quan

| IP liên quan | INTMAP cần gì / IP đó cần gì |
|---|---|
| 8 loại peripheral | INTMAP cần đúng port và width như Table 7-1; nguồn level phải giữ tới khi clear. Peripheral không cần gì từ INTMAP: không ack, không thanh ghi |
| WDT | INTMAP cần bark là level giữ. WDT cần bark không bị mask, nên nó có wire riêng tới `irq_nm_i` |
| Ibex | INTMAP dùng `irq_fast_i[10:0]` và `irq_nm_i`. Ibex lo priority, mask (`mie`, `mstatus.MIE`) và vector |
| `design/top` | Instantiate INTMAP, và tie `irq_fast_i[14:11]`, `irq_external_i`, `irq_timer_i`, `irq_software_i` về 0 |
| Firmware | Vector table ở `mtvec + 0x40` tới `+0x68` và `+0x7C`; `mtvec` 256-byte aligned; cài handler trước khi set `mstatus.MIE`, cài entry NMI trước khi bật watchdog; clear interrupt của peripheral trước khi đóng `CLK_EN` |
| SCRC | Không cần thay đổi; luật clock gate nằm ở firmware |

## 3. Giải thích từng hình

### Figure 3-1. INTMAP: 5 OR gates and 6 wires onto irq_fast_i[10:0], one wire onto irq_nm_i

Hình này trả lời một câu: mỗi nguồn interrupt đi vào chân nào của Ibex, qua OR hay qua
wire, và chân nào của Ibex không do INTMAP lái.

**Khung tổng.** Thưa thầy, em đọc từ trái sang phải. Cột trái là các nguồn. Ở giữa là
khung nét đứt ghi `INTMAP`, chính là module `m_qnsc_intmap`. Giữa INTMAP và Ibex là các
nhãn output. Bên phải là khung viền liền ghi `Ibex`, mỗi ô trong đó là một chân interrupt
của core. Góc dưới có một khung nét đứt nhỏ ghi `design/top`, là các tie-off. Mỗi hàng là
một đường đi trọn vẹn, và em đọc từ trên xuống.

**Đọc trọn một line wire: hàng đầu, DMA.** Ô nguồn ghi `DMA` và `dma_irq_o · level`, tức
là port gốc của khối DMA tên `dma_irq_o`, và nó là level, giữ tới khi firmware W1C
`DMA_ISR`. Mũi tên vào ô INTMAP ghi `i_int_dma` và `wire`, tức là port 1 bit, nối thẳng,
không có cổng nào. Ra khỏi INTMAP là nhãn `o_int_fast[0]`. Mũi tên đi vào ô Ibex ghi
`irq_fast_i[0] mcause 16`, tức là chân fast 0, và khi trap thì `mcause` = 16, vector
`mtvec + 0x40`. Line 0 có priority cao nhất trong các fast line.

**Đọc trọn một line OR: hàng hai, SPI device.** Ô nguồn ghi `SPI device` và
`intr_*_o ×8 · level`, tức là 8 port `intr_*_o`, cả 8 đều level. Ô INTMAP ghi
`i_int_spi_device[7:0]` và `OR`: port 8 bit, OR lại thành một. Chỉ cần 1 trong 8 lên là
line lên; line chỉ rơi khi cả 8 đã được W1C `INTR_STATE`. Ra nhãn `o_int_fast[1]`, vào ô
`irq_fast_i[1] mcause 17`. Đây là OR 8 input, path sâu nhất của khối.

**Cột nguồn, các ô còn lại, từ trên xuống.**
- `SPI host` · `intr_error_o, intr_spi_event_o · level`: 2 nguồn, lỗi và event.
- `I2C` · `interrupt_o · level`: 1 nguồn, clear bằng `IACK`.
- `UART0` · `INT · level` và `UART1` · `INT · level`: mỗi UART 1 nguồn, cùng tên port
  `INT`.
- `TIMER1` · `irq_lo_o, irq_hi_o · pulse/level`: 2 nguồn; "pulse/level" nghĩa là pulse,
  nhưng là level khi chạy one-shot có prescaler hoặc ref clock.
- `PWM` · `events_o[3:0] · pulse`: 4 event, đều pulse.
- `WDT` · `intr_wkup_timer_expired_o · level`: wake-up timer của watchdog.
- `GPIO0-2` · `interrupt ×3 · pulse`: 3 instance GPIO, mỗi cái một chân `interrupt`.
- `TIMER0` · `irq_lo_o · pulse/level`: chỉ `irq_lo_o`, vì TIMER0 chạy 64-bit mode.
- Ô cuối viền đậm, `WDT` · `nmi_wdog_timer_bark_o · level`: bark của cùng watchdog đó.
  Viền đậm là để tách đường NMI ra khỏi các fast line.

**Cột INTMAP, các ô còn lại.** Quy tắc chỉ có một: port 1 bit ghi `wire`, port nhiều bit
ghi `OR`.
- Ghi `OR`: `i_int_spi_host[1:0]`, `i_int_timer_1[1:0]`, `i_int_pwm[3:0]`,
  `i_int_gpio[2:0]`. Cộng `i_int_spi_device[7:0]` là đủ 5 cổng OR.
- Ghi `wire`: `i_int_i2c`, `i_int_uart_0`, `i_int_uart_1`, `i_int_wdt_wakeup`,
  `i_int_timer_0`. Cộng `i_int_dma` là đủ 6 wire cho fast line.
- Ô viền đậm `i_int_wdt_bark` · `wire`: wire thứ 7, dành cho NMI.

**Nhãn output.** `o_int_fast[0]` tới `o_int_fast[10]`, mỗi nhãn là một bit của port
`o_int_fast` 11 bit, đi theo đúng hàng của nó. Nhãn cuối `o_int_nm` là output 1 bit cho
NMI. Không có flop nào giữa port vào và nhãn ra.

**Cột Ibex.** Các ô `irq_fast_i[2] mcause 18`, `irq_fast_i[3] mcause 19`,
`irq_fast_i[4] mcause 20`, `irq_fast_i[5] mcause 21`, `irq_fast_i[6] mcause 22`,
`irq_fast_i[7] mcause 23`, `irq_fast_i[8] mcause 24`, `irq_fast_i[9] mcause 25`,
`irq_fast_i[10] mcause 26` theo cùng một luật: `mcause` = 16 + *n*, vector
`mtvec + 4·mcause`. Ô viền đậm `irq_nm_i mcause 31` là chân non-maskable, không bị `mie`
hay `mstatus.MIE` chặn, vector `mtvec + 0x7C`.

**Khung `design/top`.** Bốn ô hằng: `4'b0` đi vào ô `irq_fast_i[14:11]`, là 4 fast line
spare, `mcause` 27-30 không bao giờ xảy ra. Ba ô `0` đi vào `irq_external_i`,
`irq_timer_i`, `irq_software_i`: QSOC không có PLIC, không có CLINT, nên ba chân này luôn
0. Các đường này nằm ở top, không đi qua INTMAP.

**Tóm lại.** 26 nguồn vào INTMAP, 12 dây ra: 5 cổng OR và 6 wire lái
`irq_fast_i[10:0]`, một wire riêng lái `irq_nm_i`. Mọi chân interrupt còn lại của Ibex
bị tie 0 ở `design/top`. INTMAP không quyết priority, không giữ pending; việc đó là của
Ibex và của từng peripheral.

**Hỏi:** `mcause` ghi trên hình, vậy INTMAP tạo ra `mcause` à?
**Đáp:** Không. Ibex tự sinh `mcause` = 16 + index của line. Hình ghi ra để thấy chân nào
ứng với `mcause` nào.

**Hỏi:** Sao bark không OR vào một fast line?
**Đáp:** Fast line bị mask bởi `mie` và `mstatus.MIE`. Watchdog phải vào được cả khi
firmware treo với interrupt đang tắt, nên nó đi `irq_nm_i`, không mask được.

**Hỏi:** Sao tie-off để ở `design/top` mà không nằm trong INTMAP?
**Đáp:** INTMAP chỉ giữ các đường có nguồn thật, nên nó có đúng 26 input bit và 12 output
bit. Nối hằng 0 vào chân không dùng là việc của top.

**Hỏi:** Hai line lên cùng lúc thì sao?
**Đáp:** Ibex lấy index nhỏ nhất trước, nên thứ tự hàng trên hình chính là priority. NMI
thắng tất cả fast line. Đổi thứ tự là phải re-synthesis.

## 4. Giải thích từng bảng

### Revision history (bảng không đánh số)

Ghi các phiên bản: V2.0 viết lại chỉ còn spec, V2.1 nói rõ NMI là wire qua khối, thêm
source port, width, shape của timer, và vẽ lại hình; V2.2 bỏ GPIO3 theo package 40 pin,
còn 26 nguồn và `i_int_gpio` 3 bit. Lý do nằm ở `_DECISIONS`.

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
- Tổng: 26 input bit, 12 output bit. Không có `i_clk_*`, không có `i_rst_n_*`.

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

**Dòng đáng chỉ:** 25 nguồn fast + 1 NMI = 26. 8 source block tính theo loại (DMA, SPI,
I2C, UART, TIMER, PWM, WDT, GPIO). 10 nguồn pulse = TIMER1 2 + PWM 4 + GPIO 3 + TIMER0 1.
11 line dùng trên 15 Ibex có, dư 4.

**Hỏi:** 8 block nhưng hình có 12 hộp nguồn?
**Đáp:** Đếm theo loại khối. SPI device và SPI host tính chung là SPI; UART0/1, TIMER0/1,
GPIO0-2 cũng vậy; WDT có 2 hộp.

**Hỏi:** NMI có được tính không?
**Đáp:** Có, nó là 1 trong 26.

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
- TIMER, PWM: pulse mất; periodic thì period sau bắn lại, one-shot thì không lặp lại.

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
- **Which event fired:** status register của nguồn; TIMER1 (lo/hi) và PWM không có.
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
- Cài handler trước khi set `mstatus.MIE`, và cài entry NMI ở `mtvec + 0x7C` trước khi bật
  watchdog, vì NMI không bị `mstatus.MIE` chặn.
- Clear interrupt của peripheral trước khi đóng `CLK_EN`; `SCRC` không cần đổi.
- HAS dòng 69 và 155 phải sửa: bark đi qua INTMAP, nên INTMAP nhận 26 nguồn
  (25 maskable + NMI). HAS cũng vẫn đếm 4 instance GPIO, trong khi QSOC chỉ có 3.

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
- GPIO: một line cho 3 instance (Day005); pin nào fire thì xem `INTSTATUS`.
- DMA là level, giữ bởi W1C `DMA_ISR`.
- Không cần latch pending trong INTMAP.
- NMI có trong tổng 26 và trong Table 10-1 (câu hỏi của thầy, 2026-09-23).
- Line của peripheral bị gate vẫn giữ mức cao.

**Hỏi:** Câu thầy hỏi hôm 23/09 đã xử lý ở đâu?
**Đáp:** Bark được đếm trong 26 ở Table 7-2, và có dòng `irq_nm_i` trong Table 10-1.

## 5. Vì sao con số này

| Con số | Ở đâu (bảng/hình) | Vì sao | Nếu khác thì sao |
|---|---|---|---|
| 26 nguồn = 25 maskable + 1 NMI | Table 7-2, Figure 3-1, Table 11-1 | Đếm từ các port interrupt output trong RTL của đúng IP đã chọn. IP được chọn raise một line mỗi khối và tự ghi event nào trong status register, nên tổng chỉ 26. Từ V2.2, GPIO3 bị bỏ theo package 40 pin. Bark là nguồn duy nhất cần non-maskable | Với bộ IP OpenTitan cũ (một line mỗi event), V1.0 đếm ra 74; khi đó 15 fast line không đủ và bắt buộc phải có controller |
| 8 source block | Table 7-2 | Đếm theo loại khối: DMA, SPI, I2C, UART, TIMER, PWM, WDT, GPIO. Các khối còn lại (SCRC, SYSCSR, ROM, SRAM, SYSDBG, bus) không có interrupt nào | Thêm một khối có interrupt thì lấy một line spare |
| 11 source group, 11 fast line driven | Table 7-2, Table 10-1, Figure 3-1 | Một group mỗi line, để `mcause` tự nói group nào; một group là một khối đã tự báo event của mình. GPIO0-2 gộp thành một group | Tách GPIO thành 3 line thì dùng 13, chỉ còn 2 spare |
| 15 fast line Ibex có, 4 spare, `irq_fast_i[14:11]` = `4'b0` | Table 7-1, 7-2, 10-1, Figure 3-1 | Ibex có `irq_fast_i` rộng 15 bit, không điều kiện (`CSR_MFIX_BIT_LOW` = 16 tới `CSR_MFIX_BIT_HIGH` = 30). 15 − 11 = 4. Input không dùng phải được lái, nên tie 0 ở `design/top` | Cần hơn 15 line, hoặc cần priority lập trình được, thì phải dùng PLIC và INTMAP không còn tồn tại |
| 12 chân core được lái; `irq_external_i`, `irq_timer_i`, `irq_software_i` = 0 | Table 10-1, Figure 3-1 | Ibex có 19 bit interrupt input; QSOC lái 11 + 1. Ba chân chuẩn cần khối mà QSOC không có: external cần PLIC, timer cần CLINT `mtime`/`mtimecmp`, software cần CLINT `msip` | Muốn dùng `irq_timer_i` cho RTOS thì phải thêm CLINT; hiện RTOS phải tự viết timer driver trên TIMER0 |
| `mcause` 16-26 và `mie` bit 16-26 | Table 7-1, 9-1, 10-1, Figure 3-1 | Ibex sinh cause của fast line *n* là `{1'b1, mfip_id}` = 16 + *n*, bằng số bit `mie` (`CSR_MFIX_BIT_LOW` = 16). Privileged spec dành cause từ 16 trở lên cho platform | Đổi core thì cách đánh số vẫn giữ, nhưng phải kiểm lại số line và chiều priority |
| `mcause` 27-30 | Table 7-1, 10-1 | Là 4 line spare, tie 0, nên không bao giờ xảy ra | -- |
| `mcause` 31 | Table 7-1, 10-1, Figure 3-1 | Ibex cố định NMI ngoài là cause 31 (`ExcCauseIrqNm`), entry thứ 32, cuối bảng | -- |
| `mcause` 11; `mip.MTIP`, `mip.MSIP` = 0 | Table 10-1 | 11 là cause chuẩn của machine external interrupt; MTIP, MSIP là bit pending chuẩn của timer và software. Các chân đó tie 0 nên không bao giờ lên | -- |
| Vector `mtvec + 0x40` … `+0x68`, `+0x7C`; 4 byte mỗi vector | Table 7-1, 11-1 | Ibex luôn ở vectored mode và tính địa chỉ `{mtvec[31:8], 1'b0, irq_vec, 2'b00}`, tức `mtvec + 4·mcause`. 4·16 = 0x40, 4·26 = 0x68, 4·31 = 0x7C | Entry thiếu ở vị trí nào thì interrupt đó nhảy vào chỗ không có handler |
| `mtvec` 256-byte aligned, `mtvec[7:0]` bị bỏ qua | Table 11-1 | Ibex chỉ lấy `mtvec[31:8]`; khi ghi, 8 bit thấp bị thay bằng hằng. `irq_vec` 5 bit nên bảng là 32 entry × 4 byte = 128 byte, nằm gọn trong 256 byte | `mtvec` không aligned thì Ibex cắt bit thấp, core nhảy sai địa chỉ |
| Line 0-10, DMA ở line 0 | Table 7-1, Figure 3-1 | Line index là priority, nhỏ thắng. Thứ tự theo luật "mất dữ liệu trước, thời gian người sau": lỡ SPI hay UART là mất byte, lỡ tick timer thì period sau có lại. DMA ở line 0 vì cả hệ thống chờ transfer xong | Đổi thứ tự là re-synthesis, và vector table của firmware đổi theo |
| SPI device 8 (`[7:0]`, `×8`) | Table 5-1, 7-1, Figure 3-1 | OpenTitan `spi_device` có đúng 8 port `intr_*_o` (5 flash, 3 TPM), sau một `INTR_STATE`. Bit theo thứ tự khai báo port | Tách 8 line thì tốn hơn nửa số fast line để lặp lại thông tin `INTR_STATE` đã có. OR 8 input cũng là path sâu nhất của khối |
| SPI host 2 (bit 0 error, bit 1 event) | Table 5-1, 7-1, Figure 3-1 | OpenTitan `spi_host` có 2 port: `intr_error_o`, `intr_spi_event_o`. Thứ tự bit: chọn theo quy ước, không có lý do bắt buộc | -- |
| GPIO 3 input trên một line (`[2:0]`, `×3`, bit *n* = GPIO*n*) | Table 5-1, 7-1, Figure 3-1 | QSOC có 3 instance GPIO (GPIO3 bị bỏ theo package 40 pin), mỗi `apb_gpio` có một chân `interrupt`. Review Day005 chốt GPIO chỉ cần một interrupt; pin nào nằm trong `INTSTATUS` | 3 line riêng thì dùng 13 line, chỉ còn 2 spare, đổi lấy việc bớt 2 lần đọc thanh ghi |
| PWM 4 (`events_o[3:0]`, bit *n* = `events_o[n]`) | Table 5-1, 7-1, Figure 3-1 | `apb_adv_timer` có port `events_o[3:0]`, mỗi event là một mux 4-trong-16 trên các channel output. Cùng một khối nên chung một line | -- |
| TIMER1 2 (bit 0 `irq_lo_o`, bit 1 `irq_hi_o`), TIMER0 1 | Table 5-1, 7-1, Figure 3-1 | `apb_timer_unit` có 2 output. TIMER1 chạy hai timer 32-bit nên dùng cả hai. TIMER0 chạy 64-bit mode (theo HAS), và nhánh 64-bit không bao giờ gán `irq_hi_o` | TIMER0 không ở 64-bit mode thì cũng cần 2 bit như TIMER1 |
| WDT 2 nguồn (wake-up line 8, bark lên NMI) | Table 5-1, 7-1, Figure 3-1 | `aon_timer` có 5 output, nối 2 cái làm interrupt. `intr_wdog_timer_bark_o` để hở vì cùng dây với NMI; bite là reset, không phải interrupt | -- |
| Width 1: DMA, I2C, UART0, UART1, WDT wake-up | Table 5-1, 7-1 | Mỗi IP chỉ có một interrupt output; nguyên nhân cụ thể nằm trong thanh ghi của IP (`DMA_ISR`, `IIR` của UART kiểu 16550, …) | -- |
| 5 OR gate, 6 wire (+1 wire NMI) | Figure 3-1, mục 7.1 | Hệ quả của width: group nhiều nguồn cần OR (SPI device, SPI host, TIMER1, PWM, GPIO), group một nguồn chỉ là wire (DMA, I2C, UART0, UART1, WDT wake-up, TIMER0) | "11 OR gate" từng được viết và đã sửa ở V2.1, vì sai |
| 26 input bit, 12 output bit, `o_int_fast` 11 bit | Table 5-1 | 1+8+2+1+1+1+2+4+1+3+1+1 = 26; 11 fast + 1 NMI = 12 | -- |
| Width 0 ở line 11-14 | Table 7-1 | Cột Width đếm nguồn trong group; line spare không có nguồn | -- |
| 10 nguồn pulse | Table 7-2 | TIMER1 2 + PWM 4 + GPIO 3 + TIMER0 1. Output của các IP này là edge detector hoặc compare một cycle; timer được đếm theo mode pulse | Timer chạy one-shot có prescaler hoặc ref clock thì là level, nên số nguồn đang pulse thực tế ít hơn |
| `IACK` bit 0 của `CMD` | Table 7-3 | Layout thanh ghi của `apb_i2c`, cố định bởi IP | -- |
| HAS dòng 69 và 155; 26 nguồn, 3 instance GPIO | Table 11-1 | HAS vẫn ghi bark đi vòng qua INTMAP và vẫn đếm 4 GPIO; MAS chốt bark là wire đi qua INTMAP và QSOC chỉ có 3 GPIO, nên INTMAP nhận 26 nguồn (25 maskable + NMI) | Không sửa thì HAS và MAS mâu thuẫn |
| V2.0, V2.1, V2.2, các ngày, Day005, V1.0 mục 3.6, `QNSC_TIMER_MAS` 7.5 | Revision history, Table 5-1, 7-3, B-1 | Số phiên bản, ngày review và chỉ mục tham chiếu tài liệu khác; chọn theo quy ước, không có lý do bắt buộc | -- |
