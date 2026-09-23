# Thuyết trình INTMAP — bản đọc

**Người viết:** Nghĩa VT · **Ngày:** 22/09/2026 · **Khớp tài liệu:** `QNSC_Interrupt_Map_MAS` **V11.10**

## Dùng file này thế nào

**Phần I là bài nói**, mười mục, đọc hết khoảng **10 phút**. Nếu bị cắt giờ thì bỏ
mục 6 và mục 10 — còn lại **7,5 phút** và vẫn đủ: bài toán, thiết kế, `mcause`, ưu
tiên, vì sao bỏ hai bản cũ, đánh đổi, và cần gì từ ai. Cắt hơn nữa thì đọc **bản ba
phút** ở cuối Phần II.

**Phần II không đọc lên.** Cùng thiết kế đó nhưng đầy đủ chiều sâu: bảng hợp đồng
đầy đủ, bằng chứng từ RTL và từ spec, ngân hàng câu hỏi. Đọc ở nhà để lúc bị cắt
ngang thì câu trả lời đã sẵn trong đầu.

Thuật ngữ kỹ thuật, tên tín hiệu, tên thanh ghi giữ nguyên tiếng Anh.

## Slide

Cả hai hình **lấy nguyên từ tài liệu INTMAP**, cộng một hình sơ đồ khối chung dùng
lúc mở đầu — nên những gì thầy thấy trên màn hình khớp đúng những gì có trong spec.

| Hình | File | Là hình nào trong tài liệu | Lúc nào |
|---|---|---|---|
| **A** | `img/fig_qsoc_full_mono.png` | sơ đồ khối QSOC (dùng chung) | mục 1 |
| **B** | `img/fig_intr_map.png` | **Figure 1** — 27 nguồn, một OR mỗi peripheral, 12 dây vào CPU | mục 3 tới 6 |
| **C** | `img/fig_intr_levels.png` | **Figure 2** — ba thiết kế, và cái bản này đánh đổi | mục 7 và 8 |

---

# PHẦN I — BÀI NÓI

## 1. Mở đầu

Em phụ trách ba khối trong QSOC, và đây là khối thứ ba: **INTMAP**, khối gom
interrupt.

Em nói trước kết luận, vì nó là điều bất ngờ nhất của bản này: **INTMAP không phải
một peripheral. Nó không có thanh ghi, không có địa chỉ, không nối vào bus, và nó
không chứa một flip-flop nào.** Toàn bộ khối là một tầng cổng OR.

Trước đây em đã viết hai bản khác: một bản tự thiết kế có sáu thanh ghi APB, rồi một
bản dùng `pulp-platform/rv_plic`. Bản này bỏ cả hai. Em sẽ nói vì sao ở mục 7, vì
phần đó chính là phần bảo vệ thiết kế.

## 2. Bài toán, nói bằng số

QSOC có **27 nguồn interrupt** đến từ tám khối peripheral. Ví dụ: SPI device có tám
nguồn, GPIO có bốn instance mỗi cái một dây, UART hai nguồn, PWM bốn, timer ba, I2C
một, DMA một, và watchdog hai — một cái báo thức, một cái là bark.

Còn CPU là **Ibex RV32IMC**. Câu hỏi kinh điển là: 27 nguồn, mà CPU chỉ có vài chân
interrupt, vậy gom thế nào?

**Nhưng con số đó là con số em đã kiểm lại, và nó không đúng như em tưởng.** Ibex
không có "vài chân". Ibex có **`irq_fast_i` rộng 15 bit** — em đọc `ibex_top.sv` và
xác nhận nó là 15 bit, không điều kiện, không tham số nào tắt được.

QSOC cần **11 đường**. Ibex cho **15**. **Chưa bao giờ có chuyện thiếu chân để phải
giải quyết.** Cả hai bản trước của em đều dựng trên tiền đề thiếu chân, và tiền đề
đó sai.

## 2b. Ba khái niệm dễ rối: source, line, mcause

Ba tầng, dây **giảm dần** qua mỗi tầng:

```
27 SOURCE ──(OR gom)──▶ 11 LINE + 1 NMI ──(vào CPU)──▶ mcause
dây VÀO INTMAP          dây RA vào CPU                 con số, không phải dây
```

- **Source** = dây interrupt đi **vào** INTMAP. Có **27** (SPI device 8, SPI host 2,
  PWM 4, TIMER1 2, GPIO 4, UART0/1, I2C, DMA, TIMER0, WDT wakeup mỗi cái 1, WDT bark 1).
- **OR** = gom các source của **cùng một peripheral** thành một dây. Ví dụ 8 dây SPI
  device → 1 (`o_irq_fast[1] = |i_spi_dev_int`). Peripheral 1 source thì nối thẳng.
- **Line** = dây đi **ra** INTMAP vào CPU. Có **11 fast line** + **1 NMI** (WDT bark
  đi thẳng, không qua INTMAP) = **12 dây vào CPU**.
- **mcause** = **không phải dây**. Khi line *n* kêu, CPU tự ghi `mcause = 16 + n` rồi
  nhảy tới handler — đây là cách CPU biết "ai gọi" mà không đọc thanh ghi nào.

**Tổng kết nối:**

| Tầng | Số dây |
|---|---:|
| Source vào INTMAP | 26 |
| WDT bark (thẳng NMI) | 1 |
| **Tổng source toàn chip** | **27** |
| Fast line ra INTMAP vào CPU | 11 |
| NMI vào CPU | 1 |
| **Tổng dây vào CPU** | **12** |

Một câu: **27 dây trong chip → INTMAP OR xuống → 12 dây thật sự vào CPU.**

## 3. Thiết kế, nói một câu

**Một cổng OR cho mỗi peripheral. Mỗi peripheral một đường `irq_fast_i`.**

Cụ thể: tám dây của SPI device OR lại thành một đường; bốn instance GPIO OR lại
thành một đường; bốn dây PWM thành một đường. Peripheral nào chỉ có một nguồn thì
nối thẳng, không cần OR.

Kết quả: **11 đường fast, cộng NMI cho watchdog bark, là 12 dây đi vào CPU.** Bốn
đường fast còn lại buộc 0, để dành.

Toàn bộ RTL của khối là mười ba dòng `assign`. Em không nói giảm cho gọn — nó thật
sự là mười ba dòng, và đó là **mục đích** của thiết kế chứ không phải tình cờ.

## 4. `mcause` làm việc mà thanh ghi từng làm

Đây là chỗ đáng chú ý nhất về mặt kiến trúc.

Khi một đường fast kêu, Ibex tự ghi số hiệu vào `mcause`. Đường số *n* cho
**`mcause` = 16 + n**. Em đọc `ibex_cs_registers.sv` và thấy đúng công thức đó.

Rồi Ibex nhảy tới **`mtvec` + 4 × `mcause`**. Em xác nhận trong `ibex_if_stage.sv`:
địa chỉ trap là `mtvec` ghép với `irq_vec`, dịch hai bit. Và **vectored mode không
tắt được** — `mtvec` bit 0 bị hardcode lên 1 cho RV32IMC.

Nghĩa là gì? **Phần cứng nhảy thẳng tới handler của đúng peripheral đó.** Không có
bước đọc thanh ghi để hỏi "ai gọi". Không có lệnh `load` nào, không có transaction
bus nào, không có chu kỳ chờ nào.

Cái mà bản PLIC phải làm bằng một thanh ghi claim ở địa chỉ `0x0C00_0000` — tức là
một lệnh đọc bus, blocking — thì bản này **phần cứng làm xong trước khi handler chạy
lệnh đầu tiên.**

Đó là lý do thiết kế này nhanh hơn, và nhanh hơn không phải vì tối ưu, mà vì **bỏ
hẳn một bước.**

## 5. Ưu tiên thì miễn phí

Ibex chọn đường nào khi hai đường kêu cùng lúc? Em đọc `ibex_cs_registers.sv`, vòng
lặp chạy từ 14 xuống 0, nên **index thấp thắng**.

Vậy **thứ tự ưu tiên chính là số hiệu đường.** Em không phải thiết kế gì cho nó,
không thanh ghi PRIO, không threshold, không arbiter.

Em xếp theo một quy tắc nói ra được: **mất dữ liệu trước, mất thời gian của người
sau.**

- **DMA giữ đường 0**, ưu tiên cao nhất. Một transfer xong mà không ai biết thì mọi
  thứ đợi nó đứng lại.
- **SPI và UART** tiếp theo. Mất một event là mất một byte, không lấy lại được.
- **PWM và timer** thấp hơn. Bỏ một nhịp thì nhịp sau lại tới.
- **GPIO gần cuối.** Cạnh tín hiệu đã được ghi vào `INTSTATUS` của chính nó, không mất.

Thứ tự này **giống đúng thứ tự hai bản trước**, nên `QSOC_HAS` không phải tranh luận
lại — chỉ cơ chế đổi, còn xếp hạng thì không.

## 6. Ba tính chất phản trực giác, em nói ra trước khi bị hỏi

**Một — khối này trong suốt ngay sau reset.** Nó không có reset, nên không có trạng
thái "chưa cấu hình". Mọi nguồn sống từ chu kỳ đầu tiên. Bản PLIC thì im lặng cho
tới khi firmware ghi `PRIO` và `IE0`. Hệ quả thực tế: **firmware phải cài handler
xong rồi mới được bật `mstatus.MIE`**, chứ không phải bật trước rồi cấu hình sau.

**Hai — không có bit pending ở đâu cả, kể cả trong CPU.** Em đọc `ibex_cs_registers.sv`
và thấy `assign mip.irq_fast = irq_fast_i;` — kèm comment của chính tác giả Ibex:
*"mip CSR is purely combinational"*. **`mip` chỉ là dây.** Core không nhớ gì.

Nên nếu một nguồn là xung một chu kỳ, và lúc đó `mstatus.MIE` đang tắt, **xung đó
mất.** Em không giấu chỗ này, nó nằm trong Table 1 và mục 5.7 của tài liệu.

**Ba — nhưng mất xung phần lớn là mất vô hại**, và đây là điều làm thiết kế đứng
được. Em đi kiểm từng nguồn xung: **mọi nguồn hoặc tự giữ dấu vết, hoặc lặp lại.**
GPIO có `INTSTATUS`. Timer và PWM thì kỳ sau lại kêu. **DMA giờ là giữ mức, không
phải xung** — `QNSC_iDMA` V2.0 lái `dma_irq_o` từ cờ `DMA_ISR` write-1-to-clear, nên
nó là mức được giữ kèm bản ghi đọc lại được, không còn là xung mất thông tin.

Nghĩa là **không nguồn nào mất thông tin.** Đây là điều kiện mà thiết kế dựa vào, và
nó đã được chốt (không còn là câu hỏi mở).

## 7. Vì sao em bỏ hai bản trước

Ba con số.

**Flip-flop: 258 cho PLIC, 52 cho bản tự làm, 0 cho bản này.**

**Cổng bus: bản PLIC chiếm `AXI_M4` trên `S_BUS`. Bản này trả lại cổng đó**, và
`APB_M15` vẫn còn trống. Một slave port ít đi là một cái crossbar nhỏ hơn, ít
constraint hơn, ít verify hơn.

**Test: 18 xuống 10, và không test nào cần bus model.** Không có thanh ghi để quét,
không có phản hồi bus để kiểm, không có trạng thái reset để xác minh, không có bắt
tay acknowledge để chứng minh — vì khối không có mấy thứ đó.

Cộng thêm một điều về tiến độ: bản PLIC phụ thuộc vào một IP **chưa từng được
elaborate** trong dự án này. Đó là rủi ro tiến độ lớn nhất của bản trước, và bản này
xoá nó hoàn toàn.

Em giữ cả hai bản cũ trong tài liệu, gọn trong **mục 6 và chỉ mục 6**. Không xoá,
vì so sánh chính là phần biện minh, và vì nếu giả định về DMA sụp thì đó là đường lui.

## 8. Cái em đánh đổi, và câu trả lời về "chuẩn"

Hai thứ.

**Ưu tiên cố định lúc elaborate.** Muốn đổi thứ tự thì phải re-synthesis, không ghi
thanh ghi được nữa. Em chấp nhận vì nguồn nhanh nhất của QSOC là UART ở 115 200
baud — một byte mỗi **87 micro-giây**. Ở tốc độ đó, ưu tiên lập trình được là thứ
không ai dùng.

**Và câu hỏi em nghĩ thầy sẽ hỏi: dùng `mcause` 16 đến 26 thì có còn là RISC-V
chuẩn không?**

Em đã đi tra spec, và câu trả lời rõ hơn em tưởng. Spec privileged bản ratified,
mục 3.1.9, nói nguyên văn: *"bits 15:0 are allocated to standard interrupt causes
only, while **bits 16 and above are designated for platform use**."*

Tức **spec dành sẵn vùng đó cho platform tự định nghĩa.** Mình dùng đúng chỗ.

Và phần rationale của chính spec còn nói thêm: các nguồn ở bit 16 trở lên *"typically
chosen to have the highest service priority **to support very fast local vectored
interrupts**"* — tức spec **khuyến nghị đúng cách mình đang làm.**

Lập luận ngược lại còn đáng chú ý hơn: spec nói `mip.MEIP` *"is set and cleared by a
platform-specific interrupt controller"*. Nghĩa là **`mcause` 11 hàm ý có một
controller.** Nếu QSOC OR tất cả về `irq_external_i` mà không có controller nào,
thì mình mới là bên dùng số hiệu không đúng ngữ nghĩa của nó.

Vậy cái thật sự riêng của Ibex chỉ còn **hai** thứ, hẹp hơn nhiều: **số đường** —
Ibex 15, không phải hằng số kiến trúc; và **chiều ưu tiên** — Ibex index thấp thắng,
còn `cv32e40s` thì ID cao thắng, ngược nhau. Cái thứ hai mới là cái đáng ghi, vì đổi
core mà không đọc lại thì thứ tự ưu tiên **đảo ngược trong im lặng.**

## 9. Em cần gì từ người khác

**DMA (đã chốt với Vinh):** `QNSC_iDMA` V2.0 lái một `dma_irq_o` là **mức giữ**, có
`DMA_ISR` đọc lại được. Nên đường 0 = DMA là cố định, không còn là câu hỏi mở.

**Từ người viết firmware:** vector table 11 entry point, `mie` bit 16 đến 26, và
thứ tự bật — **cài handler trước, bật `mstatus.MIE` sau.**

## 10. Kết

INTMAP là khối nhỏ nhất trong ba khối em phụ trách, và nó nhỏ vì em bỏ được hai
thiết kế lớn hơn.

**Không flip-flop. Không clock. Không reset. Không thanh ghi. Không địa chỉ. Không
cổng bus.** Mười một cổng OR, 12 dây vào CPU, và `mcause` làm nốt phần việc còn lại.

Điều em muốn nói cuối là về cách làm: hai bản trước đều đúng ở chỗ chúng dựng trên
một tiền đề — *Ibex không nhớ gì nên phải có latch ở ngoài*. Tiền đề đó đúng. **Chỉ
là nó hẹp hơn câu em viết ra:** phần lớn nguồn tự nhớ giùm rồi, nên cái latch đó
hầu hết là dư. Em chỉ thấy được điều đó khi đi đọc RTL của từng peripheral, chứ
không phải khi đọc lại thiết kế của mình.

---

# PHẦN II — KHÔNG ĐỌC LÊN

## Table 6 — bảng hợp đồng, bản đầy đủ

Đây là **hợp đồng** của khối: nó cố định cả cách nối dây và, vì index *chính là* ưu
tiên, cả thứ tự ưu tiên mặc định. Vector table của firmware phụ thuộc vào bảng này.

| Đường | `mcause` | Vector | Peripheral | Số nguồn OR | Dạng |
|---:|---:|---|---|---:|---|
| `0` | 16 | `mtvec + 0x40` | **DMA** | 1 | level |
| `1` | 17 | `mtvec + 0x44` | **SPI device** | 8 | level |
| `2` | 18 | `mtvec + 0x48` | **SPI host** | 2 | level |
| `3` | 19 | `mtvec + 0x4C` | **I2C** | 1 | level |
| `4` | 20 | `mtvec + 0x50` | **UART0** | 1 | level |
| `5` | 21 | `mtvec + 0x54` | **UART1** | 1 | level |
| `6` | 22 | `mtvec + 0x58` | **TIMER1** | 2 | pulse |
| `7` | 23 | `mtvec + 0x5C` | **PWM** | 4 | pulse |
| `8` | 24 | `mtvec + 0x60` | **WDT wakeup** | 1 | level |
| `9` | 25 | `mtvec + 0x64` | **GPIO0 – GPIO3** | 4 | pulse |
| `10` | 26 | `mtvec + 0x68` | **TIMER0** | 1 | pulse |
| `11` – `14` | 27 – 30 | — | **spare**, buộc 0 | 0 | — |
| — | **31** | `mtvec + 0x7C` | **WDT bark** trên `irq_nm_i` | 1 | level |

**Tổng 26 nguồn trên 11 đường, cộng NMI. Hai mươi bảy.**

Ba chân chuẩn còn lại — `irq_external_i`, `irq_timer_i`, `irq_software_i` — **buộc 0**.
QSOC không có CLINT nên không có timer interrupt hay software interrupt ở mức core.

## Toàn bộ RTL

```systemverilog
assign o_irq_fast[0]  = i_dma_int;          // 1 nguồn
assign o_irq_fast[1]  = |i_spi_dev_int;     // 8 nguồn OR lại
assign o_irq_fast[2]  = |i_spi_host_int;    // 2
assign o_irq_fast[3]  = i_i2c_int;          // 1
assign o_irq_fast[4]  = i_uart0_int;        // 1
assign o_irq_fast[5]  = i_uart1_int;        // 1
assign o_irq_fast[6]  = |i_timer1_int;      // 2
assign o_irq_fast[7]  = |i_pwm_int;         // 4
assign o_irq_fast[8]  = i_wdt_wkup_int;     // 1
assign o_irq_fast[9]  = |i_gpio_int;        // 4 instance OR lại
assign o_irq_fast[10] = i_timer0_int;       // 1
assign o_irq_fast[14:11] = 4'b0;            // để dành
assign o_irq_nm       = i_wdt_nmi;          // đi thẳng
```

**Có một test lint kiểm rằng module không có `clk_i`, không có `rst_ni`, không có
`always_ff`.** Nếu bất kỳ cái nào xuất hiện thì thiết kế đã trôi ngược về làm
controller, và test đó bắt được.

## Cái gì không có trong khối, và ai làm thay

| Không có | Ai làm thay |
|---|---|
| Pending latch | Thanh ghi trạng thái của chính peripheral, hoặc không ai — mục 4.4 tài liệu |
| "Event nào kêu" | Thanh ghi trạng thái của peripheral, đọc trong handler |
| "Peripheral nào kêu" | **`mcause`**, qua địa chỉ trap vectored |
| Giải quyết ưu tiên | Ibex, theo index đường fast |
| Enable từng nguồn | `mie` bit 16 đến 26, trong core |
| Acknowledge | Ghi thanh ghi trạng thái của peripheral, việc firmware vốn đã phải làm |

## Bằng chứng — mỗi khẳng định lấy từ đâu

| Khẳng định | Bằng chứng |
|---|---|
| **`mip` thuần tổ hợp, core không nhớ gì** | `ibex_cs_registers.sv`: `assign mip.irq_fast = irq_fast_i;` kèm comment của tác giả *"mip CSR is purely combinational"* |
| **`irq_fast_i` rộng 15 bit**, không điều kiện | `ibex_top.sv` |
| **`mcause` của đường *n* = 16 + n** | `ibex_cs_registers.sv`: `lower_cause: {1'b1, mfip_id}` |
| **Index thấp thắng** | `ibex_cs_registers.sv`: `for (int i = 14; i >= 0; i--) if (irqs_i.irq_fast[i]) mfip_id = i[3:0];` |
| **Địa chỉ trap = `mtvec` + 4 × `mcause`** | `ibex_if_stage.sv`: `EXC_PC_IRQ: exc_pc = {csr_mtvec_i[31:8], 1'b0, irq_vec, 2'b00};` — `irq_vec` 5 bit → 32 entry × 4 B = **128 B** |
| **Vectored mode không tắt được** | `mtvec_d = {boot_addr_i[31:8], 6'b0, 1'b0, ~(...)}` → bit 0 = 1 với RV32IMC thường |
| **Thứ tự ưu tiên** | NMI → **fast** → external → software → timer |
| **`mcause` ≥ 16 là vùng platform** | Spec privileged, Machine ISA 1.13 ratified, mục 3.1.9 + Table 14: *"bits 16 and above are designated for platform use"* |
| **Spec khuyến nghị đúng cách này** | Cùng mục: nguồn ở bit 16+ *"typically chosen to have the highest service priority to support very fast local vectored interrupts"* |
| **`mcause` 11 hàm ý có controller** | Cùng mục: *"MEIP is read-only in `mip`, and is set and cleared by a platform-specific interrupt controller"* |
| **Chiều ưu tiên là tuỳ implementation** | Ibex index thấp thắng; `cv32e40s` **ID cao thắng**, và manual của nó gọi bit trên của `mie`/`mip` là *"an intended custom extension in the RISC-V CLINT mode interrupt architecture"* |
| **GPIO tự giữ dấu vết** | `apb_gpio` có `INTSTATUS`; output `interrupt` là một bit mỗi instance, lấy thẳng từ edge detector |
| **Timer là xung** | `apb_adv_timer`: `events_o[0] = s_event_en[0] & r_event_sync_0[1] & ~r_event_sync_0[0]` → edge detector |

## Ngân hàng câu hỏi

**"27 nguồn mà CPU chỉ có mấy chân, em gom kiểu gì?"**

Câu hỏi này dựa trên một tiền đề không đúng, và em nên chỉnh nhẹ nhàng. Ibex không
có "mấy chân" — nó có `irq_fast_i` **15 bit**, em đọc `ibex_top.sv` để chắc. QSOC
cần 11. Không thiếu. Việc gom là gom **trong một peripheral** cho gọn dây, chứ không
phải gom vì hết chân.

**"Không có pending bit thì mất interrupt chứ?"**

Có, và em không giấu. Nếu nguồn là xung một chu kỳ và `mstatus.MIE` đang tắt thì xung
mất. Nhưng em đã kiểm từng nguồn: **mọi nguồn hoặc tự giữ dấu vết, hoặc lặp lại** —
GPIO có `INTSTATUS`, timer và PWM kỳ sau lại kêu, và **DMA giờ là mức giữ** (iDMA
V2.0, `DMA_ISR` write-1-to-clear) chứ không phải xung. Nên **không nguồn nào mất
thông tin** — điều này đã chốt, không còn là câu hỏi mở.

**"Sao không dùng PLIC cho chuẩn?"**

Ba con số: **258 flip-flop, một cổng `AXI_M4`, và 18 test**. Bản này là **0, không
cổng nào, 10 test** và không test nào cần bus model. Thêm nữa PLIC bắt một lệnh đọc
claim blocking trước khi biết ai gọi, còn ở đây `mcause` đã nói xong trước khi
handler chạy lệnh đầu. Và PLIC là IP **chưa từng elaborate** trong dự án — rủi ro
tiến độ lớn nhất của bản trước.

**"`mcause` 16 đến 26 có chuẩn không?"**

Có. Spec privileged mục 3.1.9 nói bit 16 trở lên *"designated for platform use"*, và
rationale của spec còn khuyến nghị đúng cách dùng này cho *"very fast local vectored
interrupts"*. Ngược lại, `mcause` 11 mới là cái **hàm ý phải có controller** — spec
nói `MEIP` được set/clear bởi *"a platform-specific interrupt controller"*. Cái riêng
của Ibex chỉ là **số đường** (15) và **chiều ưu tiên** (index thấp thắng, ngược với
`cv32e40s`).

**"Sao không OR hết về một đường `irq_external_i` cho đơn giản?"**

Vì lúc đó `mcause` chỉ nói "có gì đó", và handler phải đi dò trạng thái của tới **14
block qua APB** để tìm ai kêu — mỗi lần đọc là một transaction blocking. Tệ hơn cả
PLIC, vì PLIC ít nhất chỉ cần **một** lần đọc claim. Mà vẫn mất priority lập trình
được. Nó thua cả hai phía.

**"Ưu tiên cố định thì có vấn đề gì?"**

Muốn đổi thì re-synthesis chứ không ghi thanh ghi được. Em chấp nhận vì nguồn nhanh
nhất của QSOC là UART 115 200 baud — một byte mỗi **87 micro-giây**. Rủi ro thật là
lúc bring-up phát hiện thứ tự sai, và khi đó cách chữa là chạy lại synthesis. Đó là
lý do em đề nghị chốt Table 6 **một lần, rõ ràng**, thay vì để nó được thừa hưởng
im lặng từ hai bản trước.

**"Tại sao xếp thứ tự này — DMA đầu, rồi SPI, UART, cuối là timer/GPIO? Dựa vào gì?"**

Không phải xếp tùy ý. **Index chính là priority** (Ibex, index thấp thắng), nên gán
peripheral vào line số mấy *tự động* là gán ưu tiên. Quy tắc gán là **"mất dữ liệu
trước, mất thời gian sau"** — với mỗi nguồn hỏi *"bỏ lỡ nó thì mất gì?"*:
- **DMA line 0**: cả hệ thống chờ transfer xong, giải phóng sớm nhất.
- **SPI, UART tiếp theo**: bỏ lỡ là mất **một byte không lấy lại được**.
- **PWM, timer, GPIO cuối**: bỏ lỡ chỉ là **trễ** — timer/PWM kỳ sau lại kêu, GPIO
  đã ghi vào `INTSTATUS` đọc lại được.

Nên mỗi vị trí trả lời được câu "bỏ lỡ nguồn này mất gì": cao = không cứu được, thấp
= cứu được hoặc lặp lại. Vì index cố định lúc elaborate, thứ tự này nên được **chốt
một lần rõ ràng** thay vì thừa hưởng im lặng.

**"GPIO bốn instance chung một đường thì handler biết cái nào?"**

`mcause` nói **là GPIO**. Rồi handler đọc `INTSTATUS` của các instance để biết
instance nào và chân nào — tối đa bốn lần đọc. Đây là một **lựa chọn**, không phải
giới hạn: tách ra bốn đường riêng thì tốn thêm 3 đường và chỉ còn 1 đường dự phòng.
Em chọn giữ 4 đường dự phòng, và nếu sau này cần tách thì đó là sửa **bốn dòng**.

**"Khối này verify thế nào nếu không có thanh ghi?"**

Mười test, không cái nào cần bus model. Nội dung: mỗi nguồn kéo đúng một đường; OR
đúng nhóm; đường dự phòng luôn 0; NMI đi thẳng; và một **test lint** kiểm module
không có `clk_i`, không `rst_ni`, không `always_ff` — nếu có thì thiết kế đã trôi
ngược thành controller.

**"Vì sao ID 21 cũ là WDT wakeup mà không phải bark?"**

Watchdog có **hai** đầu ra. **Bark** là cái nguy hiểm, nó đi `irq_nm_i` làm NMI với
`mcause` 31, vì NMI không maskable được — nếu firmware treo và tắt interrupt thì
bark vẫn tới. **Wakeup** là cái thường, dùng để đánh thức khỏi WFI, nên nó đi đường
fast bình thường (đường 8).

## Bản ba phút

Nếu bị cắt giờ, đọc đúng phần này.

INTMAP gom 27 nguồn interrupt từ tám peripheral về CPU Ibex.

**Khối này không phải peripheral. Không thanh ghi, không địa chỉ, không cổng bus,
không một flip-flop nào.** Toàn bộ là một tầng cổng OR — mười ba dòng `assign`.

Cách làm: **một cổng OR mỗi peripheral, mỗi peripheral một đường `irq_fast_i`.** 11
đường, cộng NMI cho watchdog bark, là 12 dây vào CPU.

Lý do làm được: **Ibex có `irq_fast_i` 15 bit**, mà QSOC chỉ cần 11 — chưa bao giờ
thiếu chân. Và khi một đường kêu, Ibex tự đặt `mcause` = 16 + index rồi nhảy tới
`mtvec` + 4 × `mcause`. **Phần cứng nhảy thẳng vào handler của đúng peripheral đó**,
không cần đọc thanh ghi nào để hỏi ai gọi. Ưu tiên cũng miễn phí: index thấp thắng,
nên em chỉ cần xếp thứ tự — DMA, SPI, UART trước; PWM, timer, GPIO sau; theo quy tắc
mất dữ liệu trước, mất thời gian sau.

So với bản PLIC em từng viết: **0 flip-flop thay vì 258**, trả lại cổng `AXI_M4`, và
10 test thay vì 18 — không test nào cần bus model.

Cái em đánh đổi và nói ra: ưu tiên cố định lúc elaborate, và nếu `mstatus.MIE` tắt
thì xung có thể mất — nhưng mọi nguồn đều tự giữ dấu vết hoặc lặp lại, kể cả DMA
(giờ là mức giữ, iDMA V2.0), nên không nguồn nào mất thông tin.
