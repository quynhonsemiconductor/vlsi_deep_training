# QNSC_UART — design decisions and record

**This is not the specification.** That is [`QNSC_UART_MAS.md`](QNSC_UART_MAS.md).

The specification is written from the research report of Ong Bao Vinh, kept whole
below. The report read the RTL of `obi_uart` line by line; its findings F1, F2, F5
and F6 were re-checked against the vendored source and hold. Its figures are not
reproduced.

---

# 1. Research report to V3.0

| Change | Why |
|---|---|
| Wrapper `m_qnsc_wrap_uart` instantiates upstream `apb_uart` unmodified | Naming Rule V1.1 names the wrapper after the block. `apb_uart` already joins `apb_to_obi` and `obi_uart`; the report rebuilt that join by hand only to reach the DMA request ports |
| DMA request ports and the patch `0001-add-dma-request-lines` dropped | `QNSC_DMA_MAS` V3.0: the DMA has no hardware request (report F9 already left them open) |
| `P_STRICT_DECODE` and the other parameters dropped; the 32-byte alias accepted | `design/README.md`, "Shared numbers": a wrapper declares no parameter. Aliasing across the window is how the other APB IP behaves (TIMER, PWM, SCRC) and is stated, not decoded away |
| `APB_M8`/`APB_M9` at `0x8002_0000`/`0x8002_4000`, `INTMAP` lines 4/5 | The report used HAS v1.3 (`APB_M9`/`APB_M10`, PLIC); the contract moved the slots when `GPIO3` was dropped, and QSOC has no PLIC |
| `i_bus_apb_paddr` 12 bits | Contract `meta.apb_paddr_width`; the report used 18 |
| Pad ports `i_pad_uart_rx`, `o_pad_uart_tx`; no `o_uart_tx_oe` | Naming Rule pad prefix; the TX pin is always an output, and direction is the IO MUX's |
| Line-status interrupt not used | Report F4: the source may last one cycle and `INTMAP` does not latch; firmware reads `LSR` per character instead |
| Stop-bit (F3), SPR and `ISR[7:6]` (F7) | F3 kept as `UART_007`; F7 stated in the register table |
| F8 (`QNSC_SoC.drawio` against HAS) | Not a UART matter; the chip diagram now follows the contract |

---

# Research report as issued

**QUY NHON SEMICONDUCTORS – QNSC**

**Báo cáo Research Core IP UART và Wrapper m_qnsc_wrap_apb_uart cho QSOC**

**Owner: Tran Van The (UART0 / UART1 — APB UART core IP và wrapper QNSC — phối hợp với Nguyen Hao Nam về ROM/Booting Flow)**

Scope: research core IP pulp-platform/apb_uart v0.2.3 (bao ngoài obi_uart của obi_peripherals v0.1.1), phân tích vi kiến trúc từ RTL, các phát hiện kỹ thuật F1–F9, thiết kế wrapper m_qnsc_wrap_apb_uart và tương thích với QSOC Boot Flow.

Project constraints: một clock ngoài 20 MHz, không PLL, không Flash — UART0 là cổng nạp ảnh boot (polling, 115 200 bps)

## Thông tin tài liệu

| **Mục** | **Nội dung** |
|:---|:---|
| Dự án | QSOC — Quy Nhon Semiconductors (QNSC) |
| Khối | UART0 (APB_M9, 0x8002_4000–0x8002_7FFF), UART1 (APB_M10, 0x8002_8000–0x8002_BFFF) |
| IP được chọn | pulp-platform/apb_uart v0.2.3, bao ngoài obi_uart của obi_peripherals v0.1.1 |
| Wrapper QNSC | m_qnsc_wrap_apb_uart — file qsoc_dma_changes/apb_uart_wrap.sv |
| Tài liệu đối chiếu | QNSC_RTL_Design_Naming_Rule.pdf (V1.0), QSOC_HAS_Report_EN_v1 3.docx, QNSC_SoC.drawio.xml, APB_UART_CoreIP_Research_Report_v2.0.docx, Booting_Flow_NguyenHaoNam.docx |
| Ngày | 24/09/2026 |
| Mục đích | Trình bày quá trình research core IP UART và bảo vệ thiết kế wrapper m_qnsc_wrap_apb_uart trước người phản biện |

**Cách đọc tài liệu.** Mỗi mục gồm bốn phần:

- **Lập luận** — viết theo văn phong kỹ thuật, mỗi kết luận truy được về một dòng RTL hoặc một bảng trong HAS.

- **Minh chứng** — trích nguyên văn đoạn RTL liên quan, kèm đường dẫn file và số dòng, để người phản biện tự đối chiếu.

- **Diễn giải** — giải thích lại bằng lời thường cho người không chuyên sâu (khung nền xanh nhạt).

- **Hình minh hoạ** — mọi sơ đồ và lưu đồ là file draw.io XML (không nén) trong diagrams/present/; ảnh PNG trong diagrams/present/png/ được xuất từ chính các file đó.

**⚠** *Toàn bộ số dòng trích dẫn được kiểm lại trực tiếp trên mã trong repo tại ngày phát hành (commit tương ứng tag upstream apb_uart v0.2.3 / obi_peripherals v0.1.1). Nếu nâng tag, số dòng có thể thay đổi.*

## Mục lục

**1. Bối cảnh: UART trong kiến trúc QSOC**

**2. Phương pháp research**

**3. Lựa chọn IP**

**4. Phân cấp IP và nguồn gốc mã**

**5. Vi kiến trúc obi_uart**

**6. Chuyển đổi giao thức APB → OBI**

**7. Bản đồ thanh ghi và cơ chế DLAB**

**8. Tạo tốc độ baud và lấy mẫu bộ thu**

**9. Bộ phát (TX)**

**10. Bộ thu (RX)**

**11. Khối ngắt**

**12. Thiết kế wrapper m_qnsc_wrap_apb_uart**

> 12.1 Kiến trúc wrapper
>
> 12.2 Mã SystemVerilog của wrapper
>
> 12.3 Bảng ánh xạ tín hiệu
>
> 12.4 Tuân thủ QNSC RTL Design Naming Rule V1.0
>
> 12.5 Sơ đồ chi tiết wrapper (F18)

**13. Tương thích với Boot Flow**

**14. Các phát hiện kỹ thuật và rủi ro**

**15. Kế hoạch kiểm chứng**

**16. Kết luận và câu hỏi cho phản biện**

**Phụ lục A. Danh mục hình**

**Phụ lục B. Tài liệu và file tham chiếu**

**Phụ lục C. Ma trận truy vết phát hiện → minh chứng → kiểm chứng**

**⚠** *Mục lục là trường TOC của Word: khi mở bằng Microsoft Word, chọn "Update Field" (hoặc F9) để hiện số trang.*

## 1. Bối cảnh: UART trong kiến trúc QSOC

### 1.1 Lập luận

QSOC là SoC 32-bit dùng lõi Ibex RV32IMC, chạy ở 20 MHz từ một nguồn clock ngoài duy nhất, không có PLL. Chip không có Flash (HAS §1), nên sau mỗi lần reset ứng dụng phải được nạp vào RAM qua cổng nối tiếp. Vì vậy UART0 là **ngoại vi quyết định khả năng khởi động**, khác với vai trò console thường thấy.

Theo HAS v1.3 (Table 5-4), hai UART là slave APB trên P_BUS:

| **Thuộc tính** | **UART0** | **UART1** | **Nguồn** |
|:---|:---|:---|:---|
| Cổng P_BUS | APB_M9 | APB_M10 | HAS Table 5-4 |
| Dải địa chỉ | 0x8002_4000–0x8002_7FFF | 0x8002_8000–0x8002_BFFF | HAS Table 5-4 |
| Kích thước slot | 16 KiB | 16 KiB | HAS Table 5-4 |
| Bus | APB4, địa chỉ 18 bit, dữ liệu 32 bit, có PSTRB, PSLVERR | như UART0 | HAS Table 5-3 |
| Ngắt PLIC | nguồn ID 13, level (le_i\[12\] = 0) | nguồn ID 14, level (le_i\[13\] = 0) | HAS Table 8-1, 8-2 |
| Clock / reset | SCRC gate bit 5, miền D06 | SCRC gate bit 6, miền D07 | HAS, SCRC |
| Chân | TX/RX qua IO MUX, mã chức năng b00 = UART0 | TX/RX qua IO MUX | HAS IO MUX |

**Bảng 1. Vị trí UART0/UART1 trong QSOC theo HAS v1.3**

Mã chức năng b00 được gán cho UART0 để ROM dùng được cổng boot mà không phải lập trình IO MUX trước.

So sánh hai nguồn cho thấy bản vẽ QNSC_SoC.drawio.xml (20/09) còn đặt INTMAP ở APB_M15 = 0x8003_C000. HAS v1.3 đã chuyển khối này thành PLIC trên S_BUS (AXI_M4, 0x0C00_0000) và giải phóng APB_M15. Báo cáo này lấy **HAS v1.3 làm chuẩn**; độ lệch được ghi thành phát hiện **F8** (mục 14).

### 1.2 Diễn giải

> ***Diễn giải:** Chip QSOC không có bộ nhớ Flash để giữ chương trình. Mỗi lần bật máy, chương trình phải được "bơm" vào qua dây UART0. Nếu UART0 hỏng thì chip không chạy được. UART nằm trên bus ngoại vi chậm (APB). Nó có một địa chỉ cố định để CPU đọc/ghi, một dây ngắt báo cho CPU, và hai chân TX/RX ra ngoài qua bộ chọn chân (IO MUX).*

*[figure not reproduced]*

**Hình 1. Vị trí UART0/UART1 trong QSOC**

*Nguồn: diagrams/present/F01_qsoc_uart_context.drawio*

## 2. Phương pháp research

### 2.1 Lập luận

Research đi theo bảy bước, và **mỗi kết luận phải truy được về một dòng RTL hoặc một bảng trong HAS**:

| **Bước** | **Nội dung** | **Đầu ra** |
|:---|:---|:---|
| B1 | Thu thập ràng buộc hệ thống từ HAS, Booting_Flow và QNSC_SoC.drawio | Sáu ràng buộc R1–R6 (mục 3) |
| B2 | Khảo sát các ứng viên IP, lọc theo ba tiêu chí: tương thích 16550, có cổng APB, giấy phép mở | Ma trận lựa chọn (Hình 3) |
| B3 | Xác minh nguồn gốc mã qua Bender.yml và diff với tag upstream (kế thừa báo cáo V2.0) | Bảng nguồn gốc mã (mục 4) |
| B4 | Đọc RTL từng module: 2 015 dòng trong 8 file obi_uart\_\*.sv | Mô tả vi kiến trúc (mục 5–11) |
| B5 | Đối chiếu ba chiều RTL ↔ HAS ↔ Boot flow; khi một phát hiện cần thêm bằng chứng thì quay lại B4 | Phát hiện F1–F9 (mục 14) |
| B6 | Thiết kế wrapper dựa trên kết quả B5 | m_qnsc_wrap_apb_uart (mục 12) |
| B7 | Lập kế hoạch kiểm chứng cho các phát hiện chưa khẳng định được bằng đọc mã tĩnh | TC-01…TC-10 (mục 15) |

**Bảng 2. Bảy bước research**

Nguyên tắc của B4–B5: **không suy diễn từ datasheet 16550 chung chung**. Mọi hành vi đều lấy từ mã thật, vì IP mã nguồn mở có thể lệch chuẩn ở chi tiết. Chính bước này tìm ra F1–F4 — những điểm không thể thấy nếu chỉ đọc tài liệu.

### 2.2 Minh chứng quy mô mã đã đọc

| **File** | **Số dòng** | **Vai trò** |
|:---|:---|:---|
| obi_uart.sv | 182 | Top core: nối các module con, loopback |
| obi_uart_register.sv | 301 | Tệp thanh ghi, giải mã địa chỉ, OBI slave |
| obi_uart_baudgen.sv | 114 | Bộ chia baud, xung oversample/double/baud |
| obi_uart_tx.sv | 310 | THR, FIFO TX, TSR, FSM phát |
| obi_uart_rx.sv | 572 | Đồng bộ, lọc đa số, FSM thu, FIFO RX, timeout |
| obi_uart_interrupts.sv | 135 | 5 nguồn ngắt, mã hoá ưu tiên, ISR |
| obi_uart_modem.sv | 132 | Đồng bộ CTS/DSR/RI/CD, delta, loopback modem |
| obi_uart_pkg.sv | 269 | Offset thanh ghi, struct bit field, giá trị reset |
| **Tổng** | **2 015** | Kết quả wc -l deps/obi_peripherals/hw/obi_uart/\*.sv |

**Bảng 3. Các file RTL đã đọc trong bước B4**

### 2.3 Diễn giải

> ***Diễn giải:** Nhóm không chỉ "chọn một IP rồi dùng". Nhóm đọc từng file mã, so từng chi tiết với yêu cầu của chip, và ghi lại mọi chỗ không khớp. Chỗ nào đọc mã chưa đủ để khẳng định thì được đưa vào danh sách phải mô phỏng.*

*[figure not reproduced]*

**Hình 2. Lưu đồ quy trình research**

*Nguồn: diagrams/present/F02_research_flow.drawio*

## 3. Lựa chọn IP

### 3.1 Lập luận

Sáu ràng buộc rút ra từ HAS được dùng làm tiêu chí chọn IP:

| **Mã** | **Ràng buộc** | **Nguồn gốc** |
|:---|:---|:---|
| R1 | Cấu hình qua APB4 trên P_BUS | HAS Table 5-3/5-4 |
| R2 | Bản đồ thanh ghi 16550, để dùng lại driver và kinh nghiệm sẵn có | Driver ROM, Booting_Flow §4.3 |
| R3 | ROM bootloader dùng polling đơn giản | Booting_Flow §5 (ROM 2 KiB) |
| R4 | Không kéo theo hệ con khác | Phạm vi phiên bản v1 |
| R5 | Một miền clock | HAS: một clock 20 MHz, không PLL |
| R6 | Giấy phép mở | Chính sách IP của dự án |

**Bảng 4. Ràng buộc chọn IP**

Ba ứng viên được so sánh:

| **Tiêu chí** | **PULP apb_uart** | **OpenTitan uart** | **PULP udma_uart** |
|:---|:---|:---|:---|
| R1 APB4 | ✔ có apb_uart_wrap với cổng struct APB | ✘ TL-UL, cần adapter | ✘ chạy trong uDMA subsystem |
| R2 16550 | ✔ 8 offset, có DLAB | ✘ bản đồ riêng, phải viết lại driver ROM | ✘ thanh ghi uDMA riêng |
| R3 polling | ✔ LSR.DR / LSR.THRE | ✔ | ✘ hướng DMA |
| R4 độc lập | ✔ | ✔ (có adapter) | ✘ cần udma_core và cầu nối L2 |
| R5 một clock | ✔ một clk_i | ✔ | ✔ |
| R6 giấy phép | ✔ SHL-0.51 | ✔ Apache-2.0 | ✔ SHL-0.51 |
| Kết luận | **Chọn** | Loại | Giữ làm phương án nâng cấp ("Hướng B", Page-3 của qnsc_soc.drawio) |

**Bảng 5. Ma trận so sánh ứng viên IP**

Kết luận: chọn apb_uart. Giữ udma_uart làm phương án nâng cấp khi hệ thống cần truyền khối lớn không qua CPU.

### 3.2 Diễn giải

> ***Diễn giải:** Bảng so sánh cho thấy chỉ apb_uart "cắm là chạy" vào bus APB của QSOC. Nó dùng kiểu thanh ghi 16550 quen thuộc nên viết chương trình nạp (bootloader) dễ, và không phụ thuộc khối nào khác. Hai lựa chọn còn lại đều cần thêm phần phụ trợ.*

*[figure not reproduced]*

**Hình 3. Ma trận lựa chọn IP**

*Nguồn: diagrams/present/F03_ip_selection.drawio*

## 4. Phân cấp IP và nguồn gốc mã

### 4.1 Lập luận

Repo apb_uart không tự hiện thực UART. Nó là ba lớp vỏ quanh obi_uart:

- \(1\) **apb_uart** (src/apb_uart.sv) — top-level kiểu cũ, cổng rời. PADDR\[2:0\] được ghép thành {PADDR, 2'b00} và PSTRB bị ép thành '1.

- \(2\) **apb_uart_wrap** (src/apb_uart_wrap.sv) — cổng struct apb_req_t/apb_rsp_t với kiểu truyền qua tham số. Dựng ObiCfg với AddrWidth = \$bits(apb_req_i.paddr) và DataWidth = 32, rồi nối apb_to_obi với obi_uart.

- \(3\) **reg_uart_wrap** (src/reg_uart_wrap.sv) — cho SoC dùng register_interface, chuyển reg_bus sang APB qua reg_to_apb.

Bên trong obi_uart có 6 module con và 1 package (số dòng ở Bảng 3). Các phụ thuộc được ghim trong Bender.yml; các primitive fifo_v3, counter, sync và macro FF lấy từ common_cells.

| **Thành phần** | **Phiên bản ghim** | **Kết quả xác minh** |
|:---|:---|:---|
| apb_uart (src/\*.sv) | v0.2.3 (CHANGELOG) | Trùng từng byte với tag upstream (báo cáo V2.0) |
| obi_peripherals (obi_uart\_\*.sv) | 0.1.1 | Trùng từng byte với tag upstream |
| apb | 0.2.4 | Trùng từng byte với tag upstream |
| obi (apb_to_obi.sv) | 0.1.7 | Dùng nguyên bản |
| register_interface | 0.3.6 | Không nằm trên đường truy cập của QSOC |
| qsoc_dma_changes/\*.sv | bản vá cục bộ | **Chưa nằm trong danh sách sources của Bender.yml** |

**Bảng 6. Nguồn gốc mã và trạng thái build**

**Minh chứng:** Bender.yml, dòng 11–20

dependencies:

apb: { git: "https://github.com/pulp-platform/apb.git", version: 0.2.4 }

obi: { git: "https://github.com/pulp-platform/obi.git", version: 0.1.7 }

obi_peripherals: { git: "https://github.com/pulp-platform/obi_peripherals.git", version: 0.1.1 }

register_interface: { git: "https://github.com/pulp-platform/register_interface.git", version: 0.3.6 }

sources:

\- src/apb_uart.sv

\- src/apb_uart_wrap.sv

\- src/reg_uart_wrap.sv \# qsoc_dma_changes/ KHÔNG có trong danh sách

**Cấu trúc được chọn làm nền cho QSOC là apb_uart_wrap.** Lớp này giữ đủ độ rộng địa chỉ của P_BUS và cho phép truyền kiểu struct của bus hệ thống. Lớp apb_uart thì cắt địa chỉ xuống 3 bit và bỏ PSTRB. Trong QSOC, lớp này được hiện thực lại thành m_qnsc_wrap_apb_uart để tên cổng tuân thủ QNSC Naming Rule (mục 12).

### 4.2 Diễn giải

> ***Diễn giải:** IP gồm nhiều lớp như búp bê Nga. Lớp trong cùng (obi_uart) mới là UART thật. Các lớp ngoài chỉ đổi "ngôn ngữ bus". QSOC chọn lớp giữa (apb_uart_wrap) vì nó nói đúng ngôn ngữ APB của chip mà không bỏ mất thông tin, rồi đổi tên nó theo quy tắc của QNSC.*

*[figure not reproduced]*

**Hình 4. Phân cấp các lớp bao của IP**

*Nguồn: diagrams/present/F04_ip_hierarchy.drawio*

## 5. Vi kiến trúc obi_uart

### 5.1 Lập luận

obi_uart được tổ chức quanh một **tệp thanh ghi trung tâm** (obi_uart_register). Tệp này giao tiếp với các khối chức năng qua hai struct định nghĩa trong obi_uart_pkg:

- **reg_read_t** chứa giá trị hiện tại của THR, IER, ISR, FCR, LCR, MCR, DLL, DLM, cùng các cờ sự kiện phần mềm obi_read_rhr, obi_read_isr, obi_read_lsr, obi_read_msr, obi_write_thr và obi_write_dllm.

- **reg_write_t** chứa các cập nhật phần cứng từ rx, tx, isr và modem. Mỗi trường có bit \*\_valid đi kèm.

Cách tổ chức này tách rõ **đường phần mềm** (bus → thanh ghi) khỏi **đường phần cứng** (khối chức năng → thanh ghi). Các khối chức năng:

| **Module** | **Chức năng chính** | **Tài nguyên lưu trữ** |
|:---|:---|:---|
| baudgen | Tạo ba xung enable: oversample ×16, double ×2 và baud | Bộ đếm 16 bit + 4 bit |
| tx | THR, FIFO, TSR, FSM phát | FIFO fifo_v3 DEPTH = 16 × 8 bit |
| rx | Đồng bộ 2 tầng, lọc đa số 3 mẫu, RSR, FIFO, RHR, timeout | FIFO fifo_v3 DEPTH = 16 × 11 bit |
| interrupts | Bộ mã hoá ưu tiên 5 nguồn, sinh ISR và irq_o | intrpt_reg_q (5 bit) |
| modem | Đồng bộ CTS/DSR/RI/CD, phát hiện sườn, loopback modem | FF đồng bộ reset về '1 |

**Bảng 7. Các module con của obi_uart**

Chế độ loopback (MCR\[4\]) được hiện thực ở top obi_uart: txd_o bị ép lên 1 và rxd nội bộ lấy từ txd. Trong khối modem, RTS được nối vòng về CTS, DTR về DSR, OUT1 về RI và OUT2 về CD. Toàn bộ khối chạy trên **một clock clk_i**, không có clock baud riêng, nên thoả R5 mà không cần CDC.

**Minh chứng:** obi_uart.sv, dòng 103–105 (loopback)

103 //--Loopback-Mode----------------------------------------------------

104 assign txd_o = (reg_read.mcr.loopback == 1'b1) ? 1'b1 : txd;

105 assign rxd = (reg_read.mcr.loopback == 1'b1) ? txd : rxd_i;

**Minh chứng:** obi_uart_rx.sv dòng 174–177 và obi_uart_tx.sv dòng 63–66 (độ sâu FIFO)

obi_uart_rx.sv 174 fifo_v3 \# ( ... 177 .DEPTH (16),

obi_uart_tx.sv 63 fifo_v3 \# ( ... 66 .DEPTH (16)

### 5.2 Diễn giải

> ***Diễn giải:** UART có một "bảng điều khiển" ở giữa (các thanh ghi). CPU ghi lệnh vào bảng và đọc trạng thái từ bảng. Các khối phát, thu, tạo nhịp và báo ngắt đều nhìn vào bảng này để làm việc. Mọi thứ chạy theo một nhịp clock chung nên không có rủi ro lệch pha giữa các miền clock.*

*[figure not reproduced]*

**Hình 5. Vi kiến trúc obi_uart**

*Nguồn: diagrams/present/F05_obi_uart_microarch.drawio*

## 6. Chuyển đổi giao thức APB → OBI

### 6.1 Lập luận

apb_to_obi (deps/obi/src/apb_to_obi.sv) là một FSM hai trạng thái:

- Ở **ADDR**, obi.req = PSEL. Khi req & gnt, FSM chuyển sang **RESP**.

- Ở **RESP**, PREADY = obi.rvalid. Khi rvalid, FSM quay về ADDR.

Phía obi_uart_register cấp gnt = req tổ hợp (dòng 51) và rvalid = req trễ 1 chu kỳ (valid_q, dòng 57 và FF). Vì vậy **mỗi truyền APB hoàn tất trong đúng 2 chu kỳ SETUP + ACCESS, không có wait-state**.

**Minh chứng:** deps/obi/src/apb_to_obi.sv, dòng 111–134

111 always_comb begin : obi_fsm

112 obi_req_o.req = 1'b0;

113 apb_rsp_o.pready = 1'b0;

114 obi_phase_d = obi_phase_q;

115 unique case (obi_phase_q)

117 ADDR: begin

119 obi_req_o.req = apb_req_i.psel;

121 if (obi_req_o.req && obi_rsp_i.gnt) obi_phase_d = RESP;

122 end

124 RESP: begin

126 if (obi_rsp_i.rvalid) begin

127 apb_rsp_o.pready = 1'b1;

128 obi_phase_d = ADDR;

129 end

130 end

132 default: obi_phase_d = ADDR;

133 endcase

134 end

**Minh chứng:** obi_uart_register.sv, dòng 46–60 (phía OBI slave)

46 always_comb begin

48 obi_rsp_o.r.rdata = rsp_data;

50 obi_rsp_o.r.err = err;

51 obi_rsp_o.gnt = obi_req_i.req; // gnt tổ hợp = req

52 obi_rsp_o.rvalid = valid_q; // rvalid trễ 1 chu kỳ

53 end

57 assign valid_d = obi_req_i.req;

58 assign word_addr_d = obi_req_i.a.addr\[AddressOffset+:AddressBits\];

Hệ quả vi kiến trúc cần lưu ý:

- \(1\) **Lệnh ghi được chốt ngay ở pha SETUP**, vì điều kiện ghi là req & we & be\[0\] (obi_uart_register.sv:149) và req đã bằng 1 từ SETUP. Điều này hợp lệ theo AMBA APB, vì PADDR, PWRITE, PWDATA và PSTRB phải ổn định từ SETUP.

- \(2\) Lệnh đọc chốt word_addr ở SETUP, rồi trả rsp_data và phát các cờ side-effect (obi_read_rhr, obi_read_lsr…) ở ACCESS.

- \(3\) PSLVERR = obi.r.err (apb_to_obi.sv:53), tức là lỗi do truy cập offset không ánh xạ (xem mục 7).

- \(4\) apb_to_obi có assertion bắt buộc penable ở RESP (dòng 143) và kiểm tra độ rộng paddr/pstrb/pwdata trùng khớp. Do đó wrapper QSOC phải truyền cùng một kiểu struct cho cả hai phía.

### 6.2 Diễn giải

> ***Diễn giải:** Bus APB và UART "nói" hai giao thức khác nhau, nên cần một bộ phiên dịch nhỏ. Bộ phiên dịch này rất gọn: mỗi lần CPU đọc/ghi mất đúng 2 nhịp clock, không bắt CPU chờ thêm. Một điểm cần nhớ khi xem dạng sóng: lệnh ghi đã có hiệu lực từ nhịp đầu tiên.*

*[figure not reproduced]*

**Hình 6. FSM apb_to_obi và giản đồ chu kỳ**

*Nguồn: diagrams/present/F06_apb_to_obi_timing.drawio*

## 7. Bản đồ thanh ghi và cơ chế DLAB

### 7.1 Lập luận

Theo obi_uart_pkg.sv, RegAlignBytes = 4, AddressBits = 3 và AddressOffset = 2. Như vậy chỉ addr\[4:2\] được giải mã, cho 8 offset cách nhau 4 byte. Mỗi thanh ghi rộng 8 bit, nằm ở wdata\[7:0\]/rdata\[7:0\]. Lệnh ghi chỉ có hiệu lực khi be\[0\] = 1.

| **Offset** | **DLAB=0 đọc** | **DLAB=0 ghi** | **DLAB=1 đọc** | **DLAB=1 ghi** | **Reset** |
|:---|:---|:---|:---|:---|:---|
| 0x00 | RHR | THR | DLL | DLL | DLL = 0x01 |
| 0x04 | IER | IER | DLM | DLM | 0x00 |
| 0x08 | ISR | FCR | **PSLVERR** | FCR | ISR đọc = 0xC1, FCR = 0x00 |
| 0x0C | LCR | LCR | **PSLVERR** | LCR | 0x00 |
| 0x10 | MCR | MCR | **PSLVERR** | MCR | 0x00 |
| 0x14 | LSR | **PSLVERR** | **PSLVERR** | **PSLVERR** | 0x60 |
| 0x18 | MSR | **PSLVERR** | **PSLVERR** | **PSLVERR** | 0x00 |
| 0x1C | SPR → 0 | bỏ qua | **PSLVERR** | bỏ qua | — |

**Bảng 8. Bản đồ thanh ghi theo DLAB, lập từ các nhánh case của obi_uart_register.sv:148–291**

| **Bit** | **LSR (0x14)** | **LCR (0x0C)** | **IER (0x04)** | **FCR (0x08, ghi)** |
|:---|:---|:---|:---|:---|
| 7 | fifo_err | dlab | — (DMA tuỳ chọn) | rx_fifo_tl\[1\] |
| 6 | tx_empty | set_break | — | rx_fifo_tl\[0\] |
| 5 | thr_empty (TX sẵn sàng) | force_par | — | — |
| 4 | break_irq (BI) | even_par | — | — (DMA) |
| 3 | frame_err (FE) | par_en | mstat | — (DMA) |
| 2 | par_err (PE) | stop_bits | rlstat | tx_fifo_rst |
| 1 | overrun (OE) | word_len\[1\] | thr_empty | rx_fifo_rst |
| 0 | **data_ready (DR)** | word_len\[0\] | dtr (DR/timeout) | fifo_en |

**Bảng 9. Trường bit của các thanh ghi dùng trong boot (obi_uart_pkg.sv:82–141)**

Bảng được lập trực tiếp từ các nhánh case ở obi_uart_register.sv:148–291. Có hai điểm **khác với 16550 chuẩn và khác với báo cáo V2.0**:

- **(F2)** Khi DLAB = 1, nhánh đọc chỉ có DLL/DLM, mọi offset khác rơi vào default: err = 1 (dòng 273–287). Báo cáo V2.0 (Table 6-2) ghi "Offsets 0x08–0x1C are unaffected by DLAB". Câu đó **đúng cho ghi nhưng sai cho đọc**. Hệ quả: nếu firmware đọc LSR hoặc LCR khi DLAB = 1 thì P_BUS trả PSLVERR, AXI2APB chuyển thành SLVERR, và Ibex sinh exception *load access fault*.

- **(F6)** Các bit paddr\[13:5\] của slot 16 KiB bị bỏ qua (dòng 58 chỉ lấy addr\[4:2\]). Mỗi thanh ghi vì thế có 512 bản sao (alias) trong slot. Wrapper m_qnsc_wrap_apb_uart ở mục 12 khoá lỗ hổng này.

**Minh chứng:** obi_uart_register.sv, dòng 273–289 (nhánh đọc khi DLAB = 1 — phát hiện F2)

273 end else begin // DLAB = 1 Address Decode

275 case (word_addr_q)

276 RegAddrDLL: begin

277 rsp_data\[RegWidth-1:0\] = reg_q.DLL;

278 end

280 RegAddrDLM: begin

281 rsp_data\[RegWidth-1:0\] = reg_q.DLM;

282 end

284 default: begin

285 err = 1'b1; // 0x08..0x1C khi DLAB=1 -\> PSLVERR

286 end

287 endcase

**Minh chứng:** obi_uart_register.sv, dòng 149–184 (nhánh ghi, DLAB = 0)

149 if (obi_req_i.req & obi_req_i.a.we & obi_req_i.a.be\[0\]) begin

153 if (~reg_q.LCR\[7\]) begin // DLAB = 0 Address Decode

155 case (word_addr_d)

156 RegAddrTHR: ... RegAddrIER: ... RegAddrFCR: ...

RegAddrLCR: ... RegAddrMCR: ... RegAddrSPR: // bỏ qua

181 default: begin

182 w_err_d = 1'b1; // unmapped register access (LSR, MSR)

183 end

### 7.2 Diễn giải

> ***Diễn giải:** UART có 8 "ô" thanh ghi, mỗi ô cách nhau 4 byte. Để tiết kiệm địa chỉ, ô 0 và ô 1 được dùng chung cho hai việc. Bit DLAB giống một công tắc: bật lên thì hai ô này chứa hệ số chia tốc độ baud, tắt đi thì chúng là ô dữ liệu và ô bật ngắt. Điểm bất ngờ là khi công tắc đang bật, đọc các ô khác sẽ báo lỗi bus thay vì trả giá trị. Chương trình phải tắt DLAB trước khi đọc trạng thái.*

*[figure not reproduced]*

**Hình 7. Giải mã địa chỉ và DLAB**

*Nguồn: diagrams/present/F07_register_decode.drawio*

## 8. Tạo tốc độ baud và lấy mẫu bộ thu

### 8.1 Lập luận

obi_uart_baudgen dùng hai bộ đếm nối tầng:

- Bộ đếm oversample 16 bit đếm từ 0 tới divisor = {DLM,DLL} − 1 (dòng 54). Mỗi lần về 0, nó tạo một xung oversample_rate_edge (dòng 77).

- Bộ đếm baud 4 bit đếm 16 xung oversample. Khi tràn, nó tạo baud_rate_edge (dòng 104). Tín hiệu double_rate_edge sinh ra khi baud_count\[2:0\] = 0.

Từ đó **f_baud = f_clk / (16 × D)** với **D = {DLM, DLL}**, khớp công thức 16550. Hai trường hợp biên rút ra từ RTL:

- **D = 1** cho divisor = 0, nên divisor_valid = 0 (dòng 56) và **toàn bộ baudgen dừng**. Đây đúng là giá trị reset (DLL = 0x01, obi_uart_pkg.sv:200). ROM **bắt buộc** phải nạp divisor trước khi dùng (**F5**).

- **D = 0** cho divisor = 0xFFFF, vẫn hợp lệ, tức là tốc độ chậm nhất. Divisor nhỏ nhất dùng được là 2, nên baud tối đa bằng f_clk / 32 = 625 000 bps ở 20 MHz.

**Minh chứng:** obi_uart_baudgen.sv, dòng 54–57, 77, 104

54 assign divisor = {reg_read_i.dlm, reg_read_i.dll} - 16'd1;

55 // divisor reset value is 0 and per the 16550A formula it has no meaning -\> invalid

56 assign divisor_valid = ~(divisor == 0);

57 assign oversample_is_divisor = (oversample_count == divisor) & divisor_valid;

77 assign oversample_rate_edge_o = (oversample_count == '0) & divisor_valid;

104 assign baud_rate_edge_o = baud_count_overflow;

**Minh chứng:** obi_uart_pkg.sv, dòng 189–201 (giá trị reset)

189 localparam uart_reg_fields_t RegResetVal = '{

197 LSR: 8'h60,

200 DLL: 8'h01, // D = 1 -\> divisor = 0 -\> baudgen dừng (F5)

201 DLM: 8'h00

Bảng baud ở 20 MHz (khớp HAS Table 13-5):

| **Baud yêu cầu** | **D** | **Baud thực = 20e6 / (16 × D)** | **Sai số** | **Dùng được** |
|:---|:---|:---|:---|:---|
| 9 600 | 130 | 9 615 | +0,16 % | Có |
| 19 200 | 65 | 19 231 | +0,16 % | Có |
| 38 400 | 33 | 37 879 | −1,36 % | Có |
| 57 600 | 22 | 56 818 | −1,36 % | Có |
| **115 200** | **11** | **113 636** | **−1,36 %** | **Có (chọn cho boot)** |
| 625 000 | 2 | 625 000 | 0 % | Có, nhưng không phải tốc độ chuẩn |

**Bảng 10. Divisor và sai số baud ở 20 MHz**

Kiểm tra lại với D = 11: bộ đếm oversample đếm 0…10 (11 chu kỳ clock), bộ đếm baud đếm 16 xung ⇒ một bit dài 11 × 16 = 176 chu kỳ ⇒ 20 000 000 / 176 = 113 636 bps. Con số này trùng với giá trị Booting_Flow §2.1 đã tính độc lập ("113,636 baud, 1.4 percent low").

Ở phía thu, obi_uart_rx đếm timing_count từ 0 đến 15 trong mỗi bit. Bộ lọc đa số lấy 3 mẫu sync_rxd ở các chu kỳ oversample 6, 7, 8 và ra quyết định ≥ 2/3. Bit được chốt vào RSR tại tâm bit (timing_count = 8, dòng 119). Cách lấy mẫu giữa bit cùng bộ lọc đa số cho phép máy thu chịu được sai lệch tần số khoảng ±2 %. Mức sai số −1,36 % ở 115 200 bps nằm trong ngân sách này.

**Minh chứng:** obi_uart_rx.sv, dòng 119 và 151–162 (bộ lọc đa số 3 mẫu)

119 assign timing_bit_center_d = (timing_count == 5'b01000) ? 1'b1 : 1'b0;

151 if (timing_count == 5'b00100) begin // Start reset in cycle 5: "Majority Init"

152 high_count_d = 2'b00;

153 end else if (oversample_rate_edge_i) begin

154 if (sync_rxd & (timing_count \< 5'b00111)) begin // Take samples in Cycle 6, 7, 8

155 high_count_d = high_count_q + 1;

156 end else if (timing_count == 5'b00111) begin

157 if ((high_count_q == 2'b10) \| (high_count_q == 2'b11) ) begin

158 filtered_rxd_d = 1'b1; // \>= 2/3 mẫu bằng 1

160 filtered_rxd_d = 1'b0;

### 8.2 Diễn giải

> ***Diễn giải:** Chip không có bộ tạo tần số, nên tốc độ truyền được tạo bằng cách chia clock 20 MHz cho một số nguyên. Chia cho 16 × 11 được 113 636 bps, lệch 1,36 % so với chuẩn 115 200. Mức lệch đó vẫn đủ nhỏ để máy tính nhận đúng. Khi nhận, UART không đọc bit ở mép mà lấy 3 mẫu ở giữa bit rồi "bỏ phiếu", nên chống được nhiễu ngắn. Lưu ý quan trọng: sau reset, bộ tạo tốc độ đứng yên cho đến khi phần mềm nạp hệ số chia.*

*[figure not reproduced]*

**Hình 8. Chuỗi bộ đếm baud và cửa sổ lấy mẫu**

*Nguồn: diagrams/present/F08_baudgen_sampling.drawio*

## 9. Bộ phát (TX)

### 9.1 Lập luận

FSM của obi_uart_tx có 7 trạng thái khai báo (TXIDLE, TXSTART, TXDATA, TXPAR, TXSTOP1, TXSTOP2, TXWAIT); TXWAIT không được dùng trong obi_uart_tx.sv (không có tham chiếu nào).

- Ở **TXIDLE**, khi FIFO không rỗng (chế độ FIFO) hoặc THR đầy (chế độ non-FIFO) và có baud_edge, FSM nạp TSR rồi chuyển sang **TXSTART** (txd = 0).

- **TXDATA** phát LSB trước, mỗi baud_edge một bit, tới word_len_bits. Dữ liệu được mask theo LCR\[1:0\].

- **TXPAR** tính parity theo LCR\[5:4\]: 00 lẻ, 01 chẵn, 10 ép 1, 11 ép 0 — đúng ngữ nghĩa stick parity của 16550.

**Điểm cần phản biện (F3).** Ở TXSTOP1 (dòng 217–225), khi LCR\[2\] = 1 FSM về IDLE ngay. Khi LCR\[2\] = 0 FSM chờ một baud_edge, sang TXSTOP2, về IDLE, rồi IDLE lại chờ baud_edge kế tiếp mới nạp ký tự. Theo trình tự đọc được, LCR\[2\] = 0 sinh khoảng 2 bit stop, còn LCR\[2\] = 1 sinh khoảng 1 bit stop. Chuẩn 16550 quy định ngược lại (LCR\[2\] = 0 là 1 stop bit).

**Minh chứng:** obi_uart_tx.sv, dòng 217–239 (TXSTOP1 / TXSTOP2 — phát hiện F3)

217 TXSTOP1: begin

218 txd_d = 1'b1;

219 if (reg_read_i.lcr.stop_bits) begin

220 // next transaction starts on next baud_rate_edge_i

221 state_d = TXIDLE; // LCR\[2\]=1 -\> về IDLE ngay

222 end else if (baud_rate_edge_i) begin

223 state_d = TXSTOP2; // LCR\[2\]=0 -\> thêm một bit-time

224 end

225 end

227 TXSTOP2: begin

228 txd_d = 1'b1;

229 if (word_len_bits == 3'b100) begin // 1.5 stop bits (5-bit word)

231 if(double_rate_edge_i) begin

232 state_d = TXIDLE;

237 end else begin

238 state_d = TXIDLE;

239 end

Ảnh hưởng thực tế thấp, vì máy thu phía host chỉ thấy thêm thời gian idle giữa hai ký tự. Nhưng thông lượng boot giảm khoảng 9 %: khung 8N1 dài 10 bit trở thành 11 bit, nên 60 KiB mất khoảng 61 440 × 11 / 113 636 ≈ 5,9 s thay vì 5,4 s. Kết luận cuối cùng phải dựa trên mô phỏng **TC-07**.

**⚠** *ROM chỉ phát vài thông báo ngắn ("CRC FAIL", "OK, JUMPING"), nên F3 không ảnh hưởng tới thời gian boot trên chiều host → chip; nó chỉ quan trọng cho ứng dụng truyền nhiều dữ liệu ra.*

### 9.2 Diễn giải

> ***Diễn giải:** Bộ phát gửi từng khung gồm bit bắt đầu, 8 bit dữ liệu (bit thấp trước), tuỳ chọn một bit chẵn lẻ, rồi bit dừng. Đọc mã, nhóm nghi rằng cài đặt "1 bit dừng" theo chuẩn thực tế lại gửi 2 bit dừng. Việc này không làm hỏng dữ liệu, chỉ làm truyền chậm hơn khoảng 9 %. Nghi vấn sẽ được kiểm chứng bằng mô phỏng.*

*[figure not reproduced]*

**Hình 9. FSM bộ phát**

*Nguồn: diagrams/present/F09_tx_fsm.drawio*

## 10. Bộ thu (RX)

### 10.1 Lập luận

Chuỗi xử lý của obi_uart_rx lần lượt là: sync 2 tầng (NrSyncStages = 2), bộ lọc đa số, FSM, RSR, rồi FIFO fifo_v3 16 × 11 bit ({PE, FE, BI, data\[7:0\]}) và cuối cùng là RHR.

FSM đi qua RXIDLE → RXSTART → RXDATA → \[RXPAR\] → RXSTOP. Ở RXSTART, nếu mẫu giữa bit start bằng 1 thì coi là glitch và quay về IDLE. Khi phát hiện framing error, FSM vào RXRESYNCHRONIZE: nếu đường truyền vẫn ở 0 thì coi đó là start bit mới.

| **Thông số** | **Giá trị / hành vi** | **Minh chứng** |
|:---|:---|:---|
| Trigger level | Chọn bằng FCR\[7:6\]: 1, 4, 8 hoặc 14 ký tự | obi_uart_pkg.sv (rx_fifo_tl) |
| Timeout ký tự | (độ dài ký tự × 4) + 1 baud khi FIFO còn dữ liệu | obi_uart_rx.sv:521–533 |
| Overrun (FIFO) | FIFO đầy mà có ký tự mới | obi_uart_rx.sv |
| Overrun (non-FIFO) | RHR chưa được đọc, RHR bị ghi đè | obi_uart_rx.sv:452 ("RHR just gets overwritten") |
| Data Ready | data_ready = write_init \| ~fifo_empty \| rhr_full_q | obi_uart_rx.sv:421 |

**Bảng 11. Thông số chức năng của bộ thu**

**Minh chứng:** obi_uart_rx.sv, dòng 521–533 (timeout ký tự)

521 // timeout_level = (character_length \* 4) +1

522 character_length = (6'd02 +word_len_bits +reg_read_i.lcr.par_en +reg_read_i.lcr.stop_bits);

523 timeout_level = (character_length \<\< 2) + 6'd01;

525 if (reg_read_i.obi_read_rhr \| write_init) begin

526 timeout_count_d = '0;

527 end else if (~fifo_empty \| rhr_full_q) begin

528 if (baud_rate_edge_i) begin

529 timeout_count_d = timeout_count_q + 1;

531 if (timeout_count_q == timeout_level) begin

532 timeout_o = 1'b1;

**Lỗi RTL (F1).** Trong nhánh non-FIFO, dòng 462 gán cứng break_irq = 1 cho **mọi ký tự nhận được**, ghi đè kết quả tính đúng ở dòng 461:

**Minh chứng:** obi_uart_rx.sv, dòng 455–465 (nhánh non-FIFO — phát hiện F1)

455 reg_write_o.rhr = rsr_q; // If full, RHR just gets overwritten

456 reg_write_o.rhr_valid = 1'b1;

459 reg_write_o.data_ready = 1'b1; // Set Data Ready Bit

460 break_interrupt = & (~{break_q, rsr_q}); // All character bits 0 ?

461 reg_write_o.break_irq = break_interrupt;

462 reg_write_o.break_irq = 1'b1; // \<-- ghi đè dòng 461: BI = 1 mọi byte

463 reg_write_o.break_valid = 1'b1;

Hệ quả: khi FCR = 0x00 (giá trị reset), LSR\[4\] (BI) luôn lên 1 sau mỗi byte. Nếu IER\[2\] bật thì ngắt RLS cũng phát ra với mỗi byte. Một bootloader kiểm tra LSR\[4:1\] để phát hiện lỗi đường truyền sẽ **báo lỗi giả ở mọi byte**. Nhánh FIFO (dòng 508) tính break_interrupt đúng và không bị ghi đè.

**Minh chứng:** obi_uart_rx.sv, dòng 508 (nhánh FIFO — không bị lỗi)

508 break_interrupt = & (~{break_q, rsr_q}); // Interrupt if all character bits are 0s

### 10.2 Diễn giải

> ***Diễn giải:** Bộ thu làm sạch tín hiệu vào, tách từng bit, rồi xếp byte vào một hàng đợi 16 chỗ. Nhóm tìm thấy một lỗi trong mã gốc: khi tắt hàng đợi (chế độ mặc định sau reset), UART luôn báo "có tín hiệu break" dù dữ liệu hoàn toàn đúng. Cách tránh đơn giản là luôn bật hàng đợi FIFO. Cách này đồng thời cho chương trình thêm thời gian xử lý.*

*[figure not reproduced]*

**Hình 10. FSM bộ thu**

*Nguồn: diagrams/present/F10_rx_fsm.drawio*

## 11. Khối ngắt

### 11.1 Lập luận

obi_uart_interrupts tính 5 nguồn ngắt, mỗi nguồn đã được AND với bit IER tương ứng:

| **Nguồn** | **Điều kiện** | **Điều kiện xoá** | **Mã ISR\[3:1\]** | **Kiểu tín hiệu vào** |
|:---|:---|:---|:---|:---|
| RLS | OE \| PE \| FE \| BI, với IER\[2\] | Đọc LSR | 011 (ưu tiên 1) | **Xung** (reg_write_i.rx.\*) |
| RXDR | trigger (FIFO) hoặc DR (non-FIFO), với IER\[0\] | FIFO dưới mức / đọc RHR | 010 (ưu tiên 2) | Mức |
| TIMEOUT | FIFO_EN & IER\[0\] & rx_timeout | Đọc RHR | 110 (ưu tiên 2) | Mức |
| THRE | THR/FIFO rỗng, với IER\[1\] | Ghi THR | 001 (ưu tiên 3) | Mức |
| MSTAT | ΔCTS, ΔDSR, TERI, ΔDCD, với IER\[3\] | Đọc MSR | 000 (ưu tiên 4) | **Xung** (delta) |

**Bảng 12. Năm nguồn ngắt của obi_uart**

ISR\[0\] = ~\|intrpt_q và ISR\[7:6\] = 11 cố định (dòng 99, 101). Đầu ra là irq_o = ~ISR\[0\], đi vào PLIC.

**Minh chứng:** obi_uart_interrupts.sv, dòng 49–66 (tính lại mỗi chu kỳ, không OR với \_q)

49 intrpt_reg_d.rls = reg_read_i.ier.rlstat & (reg_write_i.rx.overrun \| reg_write_i.rx.par_err \|

50 reg_write_i.rx.frame_err \| reg_write_i.rx.break_irq);

53 if (reg_read_i.fcr.fifo_en) begin

54 intrpt_reg_d.rxdr = reg_read_i.ier.dtr & rx_fifo_trigger; // FIFO mode

55 end else begin

56 intrpt_reg_d.rxdr = reg_read_i.ier.dtr & reg_write_i.rx.data_ready; // THR mode

57 end

60 intrpt_reg_d.timeout = reg_read_i.fcr.fifo_en & reg_read_i.ier.dtr & rx_timeout;

63 intrpt_reg_d.thr_empty = reg_read_i.ier.thr_empty & reg_write_i.tx.thr_empty;

66 intrpt_reg_d.mstat = reg_read_i.ier.mstat & (reg_write_i.modem.d_cts \| ... );

**Minh chứng:** obi_uart_interrupts.sv, dòng 11 và 107–120 (chú thích file và bộ mã hoá ưu tiên)

11 /// Calculated interrupts and stores them until reset by hardware or by reading the ISR register

107 if (intrpt_reg_q.rls) begin reg_isr_o.id = 3'b011;

110 end else if (intrpt_reg_q.rxdr) begin reg_isr_o.id = 3'b010;

113 end else if (intrpt_reg_q.timeout) begin reg_isr_o.id = 3'b110;

116 end else if (intrpt_reg_q.thr_empty) begin reg_isr_o.id = 3'b001;

119 end else if (intrpt_reg_q.mstat) begin reg_isr_o.id = 3'b000;

**Quan sát cần kiểm chứng (F4).** intrpt_reg_d được **tính lại hoàn toàn mỗi chu kỳ** từ tín hiệu hiện tại (dòng 49–66), không OR với intrpt_reg_q. Ba nguồn RXDR, TIMEOUT và THRE bám theo trạng thái nên là **mức thật**. Nhưng RLS dựa trên overrun, par_err, frame_err và break_irq từ reg_write_i.rx, còn MSTAT dựa trên các delta — đều là **xung một chu kỳ** (chỉ có mặt khi \*\_valid). Vì vậy irq_o do RLS/MSTAT gây ra có thể chỉ rộng 1 chu kỳ, trái với chú thích "stores them until reset" ở dòng 11 và với khai báo *Level* của HAS.

**⚠** *Cần kiểm tra gateway PLIC có bắt được xung 1 chu kỳ ở chế độ level hay không (TC-08). Giảm thiểu tạm thời: firmware không dựa vào IER\[2\]/IER\[3\] mà đọc LSR/MSR khi phục vụ ngắt RX. ROM boot dùng polling (IER = 0x00) nên không chịu ảnh hưởng.*

### 11.2 Diễn giải

> ***Diễn giải:** UART có 5 lý do để "gọi" CPU: có dữ liệu mới, hết thời gian chờ, sẵn sàng gửi tiếp, có lỗi đường truyền, và tín hiệu modem thay đổi. Ba lý do đầu giữ "chuông" kêu cho tới khi CPU xử lý. Hai lý do sau, theo mã hiện tại, chỉ bấm chuông một nhịp clock rất ngắn, nên có nguy cơ bộ điều khiển ngắt bỏ lỡ. Việc này cần mô phỏng để chắc chắn.*

*[figure not reproduced]*

**Hình 11. Khối ngắt và mã hoá ưu tiên**

*Nguồn: diagrams/present/F11_interrupt_priority.drawio*

## 12. Thiết kế wrapper m_qnsc_wrap_apb_uart

### 12.1 Kiến trúc wrapper

#### ***Lập luận***

Wrapper được hiện thực trong file qsoc_dma_changes/apb_uart_wrap.sv, dưới tên module m_qnsc_wrap_apb_uart. Nó thay cho lớp apb_uart_wrap của upstream và giữ nguyên cấu trúc bên trong: apb_to_obi nối với obi_uart. Có hai nguyên tắc thiết kế:

- **Không sửa logic lõi.** apb_to_obi được dùng nguyên bản. obi_uart chỉ khác upstream ở bản vá DMA đã có trong qsoc_dma_changes/, gồm hai cổng yêu cầu DMA.

- **Chuẩn hoá tại biên wrapper.** Mọi cổng hướng ra QSOC đều theo *QNSC RTL Design Naming Rule V1.0* (mục 12.4). Kiểu struct và tên cổng của IP bên thứ ba chỉ còn nằm bên trong wrapper.

Wrapper gồm bốn thành phần:

| **\#** | **Thành phần** | **Hiện thực** | **Lý do / minh chứng** |
|:---|:---|:---|:---|
| 1 | Bộ giải mã offset (P_STRICT_DECODE, mặc định 1) | w_addr_hit = (i_bus_apb_paddr\[13:5\] == 0). Nếu psel & !w_addr_hit: pready = 1, pslverr = 1, prdata = 0, che psel của core | Khoá 511 vùng alias (F6). Chỉ là bộ so sánh 9 bit tổ hợp, **không thêm chu kỳ trễ**, giữ 0 wait-state |
| 2 | Tie-off modem | cts_ni = dsr_ni = ri_ni = cd_ni = 1'b1; rts_no, dtr_no, out1_no, out2_no để hở | FF đồng bộ modem reset về '1 (obi_uart_modem.sv:110–113) ⇒ tie 1 không sinh delta giả. TX không bị CTS chặn (không có tham chiếu cts trong obi_uart_tx.sv) |
| 3 | Cổng yêu cầu DMA | o_dma_tx_req = ~thr_full_q (obi_uart_tx.sv:308 bản vá), o_dma_rx_req = rx_fifo_trigger (obi_uart.sv:169 bản vá) | Để hở ở top-level cho tới khi DMA QSOC có handshake ngoại vi (F9) |
| 4 | Giao tiếp IO MUX | o_gpio_uart_tx, o_gpio_uart_tx_oe = 1'b1; i_gpio_uart_rx nối thẳng rxd_i | RX đã có sync 2 tầng trong core. **Yêu cầu IO MUX: cấp 1'b1 khi chân không chọn UART**, nếu không bộ thu thấy break liên tục |

**Bảng 13. Bốn thành phần của wrapper**

**Minh chứng:** obi_uart_modem.sv, dòng 110–113 (giá trị reset của FF đồng bộ modem)

110 \`FF(sync_cts_n_q, sync_cts_n_d, '1, clk_i, rst_ni)

111 \`FF(sync_dsr_n_q, sync_dsr_n_d, '1, clk_i, rst_ni)

112 \`FF(sync_ri_n_q, sync_ri_n_d, '1, clk_i, rst_ni)

113 \`FF(sync_cd_n_q, sync_cd_n_d, '1, clk_i, rst_ni)

Clock và reset lấy trực tiếp từ SCRC qua i_clk_peri và i_rst_n_peri. SCRC nối vào đây clock đã gate bit 5/6 và reset đã đồng bộ theo miền D06/D07. Do đó wrapper không chứa logic reset riêng.

#### ***Diễn giải***

> ***Diễn giải:** Wrapper giống một "ổ cắm chuyển đổi" giữa IP có sẵn và chip QSOC. Nó không động vào phần lõi của IP. Nó làm bốn việc: (1) chặn các địa chỉ rác trong vùng 16 KiB để lập trình sai thì báo lỗi ngay; (2) cố định các chân modem không dùng về trạng thái an toàn; (3) đưa sẵn dây yêu cầu DMA ra ngoài cho giai đoạn sau; (4) nối TX/RX ra bộ chọn chân, với yêu cầu RX phải được giữ ở mức 1 khi không dùng. Mọi cổng ra ngoài đều đặt tên theo quy tắc chung của QNSC.*

*[figure not reproduced]*

**Hình 12. Sơ đồ khối wrapper m_qnsc_wrap_apb_uart**

*Nguồn: diagrams/present/F12_qsoc_uart_wrap_block.drawio*

### 12.2 Mã SystemVerilog của wrapper

Mã dưới đây là nội dung đầy đủ của qsoc_dma_changes/apb_uart_wrap.sv (143 dòng), đã đối chiếu từng dòng với file trong repo.

1 // Copyright 2025 ETH Zurich and University of Bologna.

2 // Solderpad Hardware License, Version 0.51, see LICENSE for details.

3 // SPDX-License-Identifier: SHL-0.51

4

5 // Paul Scheffler \<paulsc@iis.ee.ethz.ch\>

6 // Nils Wistoff \<nwistoff@iis.ee.ethz.ch\>

7 //

8 // QNSC: derived from apb_uart_wrap, renamed and normalized at the wrapper

9 // boundary per QNSC RTL Design Naming Rule V1.0 (DM/RULES/FE).

10

11 \`include "apb/typedef.svh"

12 \`include "obi/typedef.svh"

13

14 // QNSC wrapper of the PULP OBI UART for the QSOC peripheral bus.

15 // One instance per port: u_uart_0 on APB_M9, u_uart_1 on APB_M10.

16 module m_qnsc_wrap_apb_uart \#(

17 parameter int unsigned P_ADDR_WIDTH = 18, // P_BUS address width

18 parameter int unsigned P_SLOT_ADDR_WIDTH = 14, // log2 of the 16 KiB slot

19 parameter bit P_STRICT_DECODE = 1'b1 // PSLVERR for slot offsets \>= 0x20

20 ) (

21 // Clock and reset from SCRC (gate bit 5 for uart_0, bit 6 for uart_1)

22 input logic i_clk_peri,

23 input logic i_rst_n_peri,

24

25 // APB4 slave (P_BUS)

26 input logic \[P_ADDR_WIDTH-1:0\] i_bus_apb_paddr,

27 input logic \[2:0\] i_bus_apb_pprot,

28 input logic i_bus_apb_psel,

29 input logic i_bus_apb_penable,

30 input logic i_bus_apb_pwrite,

31 input logic \[31:0\] i_bus_apb_pwdata,

32 input logic \[3:0\] i_bus_apb_pstrb,

33 output logic \[31:0\] o_bus_apb_prdata,

34 output logic o_bus_apb_pready,

35 output logic o_bus_apb_pslverr,

36

37 // Interrupt to PLIC (source 13 for uart_0, 14 for uart_1, level)

38 output logic o_int_uart,

39

40 // DMA request lines for the QSOC peripheral-triggered DMA channels

41 output logic o_dma_tx_req,

42 output logic o_dma_rx_req,

43

44 // Serial pins towards IO MUX (RX must be driven idle-high when unselected)

45 input logic i_gpio_uart_rx,

46 output logic o_gpio_uart_tx,

47 output logic o_gpio_uart_tx_oe

48 );

49

50 localparam int unsigned P_DATA_WIDTH = 32; // P_BUS data width (fixed)

51

52 \`APB_TYPEDEF_ALL(apb, logic \[P_ADDR_WIDTH-1:0\], logic \[P_DATA_WIDTH-1:0\], logic \[P_DATA_WIDTH/8-1:0\])

53

54 localparam obi_pkg::obi_cfg_t C_OBI_CFG = obi_pkg::obi_default_cfg(

55 P_ADDR_WIDTH,

56 P_DATA_WIDTH,

57 1,

58 obi_pkg::ObiMinimalOptionalConfig

59 );

60

61 \`OBI_TYPEDEF_DEFAULT_ALL(obi, C_OBI_CFG)

62

63 logic w_addr_hit;

64 apb_req_t w_apb_req;

65 apb_resp_t w_apb_rsp;

66 obi_req_t w_obi_req;

67 obi_rsp_t w_obi_rsp;

68

69 // Offset decode: only 0x00..0x1C of the slot hold UART registers

70 if (P_STRICT_DECODE) begin : gen_strict_decode

71 assign w_addr_hit = (i_bus_apb_paddr\[P_SLOT_ADDR_WIDTH-1:5\] == '0);

72 end else begin : gen_no_decode

73 assign w_addr_hit = 1'b1;

74 end

75

76 // Flat QNSC APB ports -\> third-party APB struct

77 assign w_apb_req = '{

78 paddr: i_bus_apb_paddr,

79 pprot: i_bus_apb_pprot,

80 psel: i_bus_apb_psel & w_addr_hit,

81 penable: i_bus_apb_penable,

82 pwrite: i_bus_apb_pwrite,

83 pwdata: i_bus_apb_pwdata,

84 pstrb: i_bus_apb_pstrb

85 };

86

87 // Out-of-range offsets complete immediately with an error, core untouched

88 always_comb begin

89 o_bus_apb_prdata = w_apb_rsp.prdata;

90 o_bus_apb_pready = w_apb_rsp.pready;

91 o_bus_apb_pslverr = w_apb_rsp.pslverr;

92 if (i_bus_apb_psel && !w_addr_hit) begin

93 o_bus_apb_prdata = '0;

94 o_bus_apb_pready = 1'b1;

95 o_bus_apb_pslverr = 1'b1;

96 end

97 end

98

99 apb_to_obi \#(

100 .ObiCfg ( C_OBI_CFG ),

101 .apb_req_t ( apb_req_t ),

102 .apb_rsp_t ( apb_resp_t ),

103 .obi_req_t ( obi_req_t ),

104 .obi_rsp_t ( obi_rsp_t )

105 ) u_apb_to_obi (

106 .clk_i ( i_clk_peri ),

107 .rst_ni ( i_rst_n_peri ),

108 .apb_req_i ( w_apb_req ),

109 .apb_rsp_o ( w_apb_rsp ),

110 .obi_req_o ( w_obi_req ),

111 .obi_rsp_i ( w_obi_rsp )

112 );

113

114 obi_uart \#(

115 .ObiCfg ( C_OBI_CFG ),

116 .obi_req_t ( obi_req_t ),

117 .obi_rsp_t ( obi_rsp_t )

118 ) u_uart (

119 .clk_i ( i_clk_peri ),

120 .rst_ni ( i_rst_n_peri ),

121 .obi_req_i ( w_obi_req ),

122 .obi_rsp_o ( w_obi_rsp ),

123 .irq_o ( o_int_uart ),

124 .irq_no ( ),

125 .dma_tx_req_o ( o_dma_tx_req ),

126 .dma_rx_req_o ( o_dma_rx_req ),

127 .rxd_i ( i_gpio_uart_rx ),

128 .txd_o ( o_gpio_uart_tx ),

129 // Modem inputs tied inactive: matches the '1 reset value of the modem

130 // synchronizers, so no delta (MSR/MSTAT) event is raised after reset

131 .cts_ni ( 1'b1 ),

132 .dsr_ni ( 1'b1 ),

133 .ri_ni ( 1'b1 ),

134 .cd_ni ( 1'b1 ),

135 .rts_no ( ),

136 .dtr_no ( ),

137 .out1_no ( ),

138 .out2_no ( )

139 );

140

141 assign o_gpio_uart_tx_oe = 1'b1;

142

143 endmodule

Ví dụ khởi tạo ở mức SoC (instance u_uart_0 trên APB_M9):

m_qnsc_wrap_apb_uart \#(

.P_ADDR_WIDTH ( 18 ),

.P_SLOT_ADDR_WIDTH ( 14 ),

.P_STRICT_DECODE ( 1'b1 )

) u_uart_0 (

.i_clk_peri ( w_clk_uart_0 ), // SCRC gate bit 5

.i_rst_n_peri ( w_rst_n_uart_0 ), // SCRC domain D06

.i_bus_apb_paddr ( w_pbus_paddr ),

.i_bus_apb_pprot ( w_pbus_pprot ),

.i_bus_apb_psel ( w_pbus_psel\[9\] ), // APB_M9

.i_bus_apb_penable ( w_pbus_penable ),

.i_bus_apb_pwrite ( w_pbus_pwrite ),

.i_bus_apb_pwdata ( w_pbus_pwdata ),

.i_bus_apb_pstrb ( w_pbus_pstrb ),

.o_bus_apb_prdata ( w_pbus_prdata\[9\] ),

.o_bus_apb_pready ( w_pbus_pready\[9\] ),

.o_bus_apb_pslverr ( w_pbus_pslverr\[9\] ),

.o_int_uart ( w_int_uart_0 ), // PLIC ID 13, le_i\[12\] = 0

.o_dma_tx_req ( ), // chưa dùng (F9)

.o_dma_rx_req ( ),

.i_gpio_uart_rx ( w_gpio_uart_0_rx ),

.o_gpio_uart_tx ( w_gpio_uart_0_tx ),

.o_gpio_uart_tx_oe ( w_gpio_uart_0_tx_oe )

);

**Ghi chú.** w_int_uart_0 đi vào PLIC ở nguồn ID 13 theo HAS Table 8-1. Bit le_i tương ứng là bit 12, vì HAS đếm le_i từ 0 cho nguồn ID 1. Instance thứ hai là u_uart_1 trên APB_M10, nguồn ID 14. Các tên w_pbus\_\*, w_gpio\_\*, w_clk\_\* chỉ để minh hoạ và phải khớp với top-level thực tế.

**⚠** *Hệ quả phụ: qsoc_dma_changes/apb_uart.sv (top-level kiểu cũ) vẫn gọi module apb_uart_wrap với cổng struct (dòng 56–59). Nếu build bản vá này cùng file đó thì phải cập nhật lại nó, hoặc loại nó khỏi danh sách build, vì QSOC không dùng lớp apb_uart.*

### 12.3 Bảng ánh xạ tín hiệu

#### ***Lập luận***

Bảng ánh xạ chốt **mỗi cổng của m_qnsc_wrap_apb_uart** với một đích trong QSOC và một lý do. Đây là **hợp đồng giao diện** giữa người sở hữu UART và người sở hữu top-level, SCRC, IO MUX và PLIC. Mọi thay đổi phải cập nhật đồng thời ở HAS.

| **Nhóm** | **Cổng wrapper** | **Hướng** | **Nối tới (QSOC)** | **Lý do** |
|:---|:---|:---|:---|:---|
| Bus | i_clk_peri | in | SCRC clock gate bit 5 / bit 6 | Miền D06 / D07 |
| Bus | i_rst_n_peri | in | SCRC reset đã đồng bộ | Wrapper không có logic reset riêng |
| Bus | i_bus_apb_paddr\[17:0\] | in | P_BUS PADDR | \[13:5\] → w_addr_hit, \[4:2\] → offset |
| Bus | i_bus_apb_pprot\[2:0\] | in | P_BUS PPROT | Bị bỏ qua trong core (UseProt = 0) |
| Bus | i_bus_apb_psel | in | P_BUS PSEL\[9\] / PSEL\[10\] | Bị che bởi w_addr_hit |
| Bus | i_bus_apb_penable, pwrite, pwdata\[31:0\], pstrb\[3:0\] | in | P_BUS | Truyền nguyên vào struct |
| Bus | o_bus_apb_prdata\[31:0\], pready, pslverr | out | P_BUS mux phản hồi | Mux với phản hồi lỗi khi miss |
| Hệ thống | o_int_uart | out | PLIC nguồn 13 / 14 (level) | Xem F4 |
| Hệ thống | i_gpio_uart_rx | in | IO MUX (idle = 1 khi không chọn) | Sync 2 tầng trong core |
| Hệ thống | o_gpio_uart_tx, o_gpio_uart_tx_oe | out | IO MUX → PAD | tx_oe = 1'b1 |
| Dự phòng | o_dma_tx_req, o_dma_rx_req | out | Để hở ở v1 | DMA QSOC chưa có kênh ngoại vi (F9) |
| Tie-off | (bên trong) cts/dsr/ri/cd_ni = 1, rts/dtr/out1/out2_no = NC, irq_no = NC | — | — | Không lộ ra biên wrapper |

**Bảng 14. Ánh xạ tín hiệu wrapper — hợp đồng giao diện**

#### ***Diễn giải***

> ***Diễn giải:** Bảng liệt kê từng dây của UART, mỗi dây nối đi đâu và vì sao. Nhờ vậy nhóm tích hợp chip không phải đoán, và người phản biện có thể kiểm từng dây một.*

*[figure not reproduced]*

**Hình 13. Ánh xạ tín hiệu wrapper**

*Nguồn: diagrams/present/F13_wrapper_signal_map.drawio*

### 12.4 Tuân thủ QNSC RTL Design Naming Rule V1.0

#### ***Lập luận***

Wrapper được đối chiếu với *QNSC RTL Design Naming Rule V1.0* (naming_rule/.../DM/RULES/FE/Release/QNSC_RTL_Design_Naming_Rule.pdf). Bản cũ apb_uart_wrap giữ nguyên quy ước của PULP và **vi phạm hầu hết các mục bắt buộc** trong checklist §4.3. Bản mới sửa như sau:

| **Mục (quy tắc)** | **Bản cũ apb_uart_wrap** | **Bản mới** | **Đạt** |
|:---|:---|:---|:---|
| QNSC wrapper (§2.1: m_qnsc_wrap\_\<ip_module\>) | apb_uart_wrap | m_qnsc_wrap_apb_uart (trùng ví dụ §2.1) | ✔ |
| Parameter (§2.4: P\_\<FUNCTION\>) | apb_req_t, apb_rsp_t; độ rộng viết cứng 32 | P_ADDR_WIDTH, P_SLOT_ADDR_WIDTH, P_STRICT_DECODE; localparam P_DATA_WIDTH = 32 | ✔ |
| Constant (§2.4: C\_\<FUNCTION\>) | ObiCfg | C_OBI_CFG | ✔ |
| Clock (§3.1: i_clk\_\<domain\>) | clk_i | i_clk_peri | ✔ |
| Reset (§1.3, §3.2: i_rst_n\_\<domain\>) | rst_ni | i_rst_n_peri | ✔ |
| APB (§3.3: i_bus_apb\_\* / o_bus_apb\_\*) | struct apb_req_i / apb_rsp_o | 7 cổng i_bus_apb\_\* + 3 cổng o_bus_apb\_\*, rời từng tín hiệu | ✔ |
| Interrupt (§3.6: o_int\_\<source\>) | intr_o | o_int_uart | ✔ |
| DMA (§3.10: o_dma\_\<function\>) | dma_tx_req_o, dma_rx_req_o | o_dma_tx_req, o_dma_rx_req | ✔ |
| GPIO (§3.7, ví dụ i_gpio_uart_rx) | sin_i, sout_o | i_gpio_uart_rx, o_gpio_uart_tx, o_gpio_uart_tx_oe | ✔ |
| Active-low (§1.3: \_n sau nghĩa tín hiệu) | cts_ni, rts_no… ở biên | Không còn ra biên, tie-off bên trong | ✔ |
| Instance (§2.2: u\_\<function\>) | i_apb_to_obi, i_obi_uart | u_apb_to_obi, u_uart | ✔ |
| Tín hiệu tổ hợp (§2.3: w\_\<function\>) | obi_req, obi_rsp | w_obi_req, w_obi_rsp, w_apb_req, w_apb_rsp, w_addr_hit | ✔ |
| Third-party IP (§4.3: chuẩn hoá tại biên) | Lộ struct và tên PULP ra ngoài | Struct PULP chỉ còn bên trong | ✔ |

**Bảng 15. Checklist QNSC Naming Rule §4.3**

**Đối chiếu với mẫu wrapper §4.1 (m_qnsc_wrap_timer).** Wrapper giữ đúng trình tự và cách đặt tên của mẫu:

| **Thành phần trong mẫu §4.1** | **Mẫu m_qnsc_wrap_timer** | **m_qnsc_wrap_apb_uart** |
|:---|:---|:---|
| Tên module | m_qnsc_wrap_timer | m_qnsc_wrap_apb_uart |
| Clock / reset | i_clk_sys, i_rst_n_sys | i_clk_peri, i_rst_n_peri (miền peri, §3.1–3.2) |
| APB vào | i_bus_apb_paddr/psel/penable/pwrite/pwdata | Giống mẫu, thêm i_bus_apb_pprot, i_bus_apb_pstrb vì P_BUS là APB4 |
| APB ra | o_bus_apb_prdata/pready/pslverr | Giống mẫu |
| Ngắt | o_int_timer_0 | o_int_uart (xem quyết định thứ nhất bên dưới) |
| Độ rộng dữ liệu | localparam P_DATA_WIDTH = 32 | localparam int unsigned P_DATA_WIDTH = 32 |
| Hằng cục bộ | C_IDLE, C_BUSY | C_OBI_CFG |
| Tín hiệu tổ hợp | w_timer_done, w_timer_match | w_addr_hit, w_apb_req, w_apb_rsp, w_obi_req, w_obi_rsp |
| Tín hiệu thanh ghi | r_timer_count, r_state | Không có: wrapper thuần tổ hợp, mọi FF nằm trong core |
| Instance core | timer u_timer_0 | obi_uart u_uart, apb_to_obi u_apb_to_obi (instance đơn, §2.2) |

**Bảng 16. Đối chiếu với mẫu wrapper §4.1**

Bốn quyết định diễn giải quy tắc mà phản biện nên xem xét:

- **Không đánh chỉ số trong tên cổng.** Ví dụ §4.1 dùng o_int_timer_0. Nhưng m_qnsc_wrap_apb_uart được khởi tạo hai lần, nên cổng đặt là o_int_uart; chỉ số nằm ở tên instance (u_uart_0, u_uart_1) và tên dây top-level (w_int_uart_0). Nếu đặt o_int_uart_0 thì instance u_uart_1 sẽ có cổng mang chỉ số 0, dễ gây nhầm.

- **Instance core không đánh chỉ số.** Mỗi wrapper chỉ chứa một core, nên dùng dạng instance đơn u_uart theo §2.2. Đường phân cấp là u_uart_0.u_uart và u_uart_1.u_uart, tránh dạng khó đọc u_uart_1.u_uart_0.

- **Miền clock/reset đặt tên peri**, theo các ví dụ §3.1–3.2. Clock đã gate riêng cho từng UART được nối ở top-level.

- **Bên trong wrapper vẫn có tên của IP bên thứ ba**: tên cổng của apb_to_obi/obi_uart (clk_i, rxd_i…), trường struct (paddr, psel…), kiểu apb_req_t/obi_req_t do macro APB_TYPEDEF_ALL/OBI_TYPEDEF_DEFAULT_ALL sinh ra, và nhãn generate gen\_\*. Checklist §4.3 chỉ đòi chuẩn hoá *tại biên wrapper*, nên các tên này được giữ.

Tên file vẫn là apb_uart_wrap.sv, vì quy tắc V1.0 không quy định tên file. Tuy vậy nên đổi thành m_qnsc_wrap_apb_uart.sv để tên file trùng tên module.

#### ***Diễn giải***

> ***Diễn giải:** QNSC có bộ quy tắc đặt tên chung để mọi khối trong chip "nói cùng một giọng": cổng vào bắt đầu bằng i\_, cổng ra bằng o\_, bus APB bằng i_bus_apb\_, ngắt bằng o_int\_, và module wrapper bằng m_qnsc_wrap\_. Wrapper cũ giữ nguyên cách đặt tên của nhóm PULP nên không khớp. Bản mới đổi toàn bộ phần nhìn thấy từ bên ngoài sang quy tắc QNSC, còn phần lõi mượn của PULP vẫn giữ tên gốc bên trong để dễ đối chiếu với mã upstream.*

*[figure not reproduced]*

**Hình 17. Chuẩn hoá tên tại biên wrapper theo QNSC Naming Rule**

*Nguồn: diagrams/present/F17_naming_compliance.drawio*

### 12.5 Sơ đồ chi tiết wrapper (F18)

Bộ sơ đồ F18 (5 trang, diagrams/present/F18_uart_wrap_detailed.drawio, sinh bằng gen_uart_wrap_detailed.py từ chính các file RTL) trình bày wrapper ở mức chân: mỗi chân core đều có đúng một nguồn — chân wrapper, net w\_\*, hằng tie-off hoặc NC.

*[figure not reproduced]*

**Hình 18-1. Block diagram chi tiết m_qnsc_wrap_apb_uart**

*Nguồn: diagrams/present/F18_uart_wrap_detailed.drawio, trang 1*

*[figure not reproduced]*

**Hình 18-2. Sơ đồ chân mặt ngoài wrapper m_qnsc_wrap_apb_uart**

*Nguồn: diagrams/present/F18_uart_wrap_detailed.drawio, trang 2*

*[figure not reproduced]*

**Hình 18-3. Sơ đồ chân top core IP (apb_to_obi, obi_uart) và struct**

*Nguồn: diagrams/present/F18_uart_wrap_detailed.drawio, trang 3*

*[figure not reproduced]*

**Hình 18-4. Nội bộ obi_uart mức chân (6 module con)**

*Nguồn: diagrams/present/F18_uart_wrap_detailed.drawio, trang 4*

*[figure not reproduced]*

**Hình 18-5. Bảng ánh xạ chân: biên wrapper ↔ net nội bộ ↔ chân core IP**

*Nguồn: diagrams/present/F18_uart_wrap_detailed.drawio, trang 5*

## 13. Tương thích với Boot Flow

### 13.1 Lập luận

Boot flow (HAS §13, Booting_Flow_NguyenHaoNam.docx) dùng UART0 ở chế độ **polling**, 115 200 bps, khung gồm MAGIC, LENGTH, LOAD_ADDR, ENTRY, PAYLOAD và CRC32. Tổ hợp phát hiện F1, F2 và F5 dẫn tới trình tự khởi tạo bắt buộc sau cho ROM:

| **Bước** | **Thao tác** | **Lý do từ RTL** |
|:---|:---|:---|
| 1 | LCR = 0x80 (DLAB = 1) | Mở truy cập DLL/DLM |
| 2 | DLL = 11, DLM = 0 | DLL reset = 1 làm baudgen dừng (**F5**). Ghi DLL/DLM xoá bộ đếm baud ngay (obi_write_dllm) |
| 3 | LCR = 0x03 (8N1, DLAB = 0) | **Phải trả DLAB = 0 trước khi đọc LSR** (**F2**). Ghi giá trị tuyệt đối, không đọc-sửa-ghi LCR |
| 4 | FCR = 0x07 | Bật FIFO và xoá RX/TX FIFO. Tránh **F1** (BI giả ở chế độ non-FIFO); 16 byte đệm cho khoảng 1,4 ms dung sai ở 113 636 bps thay vì khoảng 88 µs |
| 5 | IER = 0x00 | Polling, không dùng ngắt, nên tránh luôn **F4** |
| 6 | Vòng chờ LSR\[0\], đọc RHR | LSR\[0\] là DR; theo RTL data_ready = write_init \| ~fifo_empty \| rhr_full (obi_uart_rx.sv:421) |
| 7 | Kiểm tra LSR\[4:1\] | Ở chế độ FIFO, các bit này phản ánh lỗi của byte ở đỉnh FIFO |

**Bảng 17. Trình tự khởi tạo UART0 trong ROM và căn cứ RTL**

Hiện thực tương ứng cho các hàm pseudocode ở Booting_Flow §4.3 (base UART0 = 0x8002_4000):

\#define UART0_BASE 0x80024000u

\#define UART_RHR (UART0_BASE + 0x00) /\* DLAB=0, đọc \*/

\#define UART_THR (UART0_BASE + 0x00) /\* DLAB=0, ghi \*/

\#define UART_DLL (UART0_BASE + 0x00) /\* DLAB=1 \*/

\#define UART_DLM (UART0_BASE + 0x04) /\* DLAB=1 \*/

\#define UART_IER (UART0_BASE + 0x04)

\#define UART_FCR (UART0_BASE + 0x08) /\* ghi \*/

\#define UART_LCR (UART0_BASE + 0x0C)

\#define UART_LSR (UART0_BASE + 0x14) /\* chỉ đọc, chỉ khi DLAB=0 (F2) \*/

\#define LSR_DR (1u \<\< 0)

\#define LSR_ERR (0xFu \<\< 1) /\* OE \| PE \| FE \| BI \*/

\#define LSR_THRE (1u \<\< 5)

\#define REG(a) (\*(volatile uint32_t \*)(a))

void uart_init(void) {

REG(UART_LCR) = 0x80; /\* 1. DLAB = 1 \*/

REG(UART_DLL) = 11; /\* 2. D = 11 -\> 113 636 bps @ 20 MHz (F5) \*/

REG(UART_DLM) = 0;

REG(UART_LCR) = 0x03; /\* 3. 8N1, DLAB = 0 - ghi tuyệt đối (F2) \*/

REG(UART_FCR) = 0x07; /\* 4. FIFO on + reset RX/TX FIFO (F1) \*/

REG(UART_IER) = 0x00; /\* 5. polling (F4) \*/

}

uint8_t uart_read(void) {

uint32_t lsr;

do { lsr = REG(UART_LSR); } while (!(lsr & LSR_DR)); /\* 6. chờ RX-not-empty \*/

/\* 7. (tuỳ chọn) if (lsr & LSR_ERR) -\> báo lỗi đường truyền \*/

return (uint8_t)REG(UART_RHR);

}

void uart_putc(uint8_t c) {

while (!(REG(UART_LSR) & LSR_THRE)) ; /\* TX sẵn sàng \*/

REG(UART_THR) = c;

}

Đối với khuyến nghị của báo cáo V2.0 (giữ FCR = 0x00 và đo vòng lặp ROM): báo cáo này đề xuất **bắt buộc FCR = 0x07**. Lý do là chế độ non-FIFO vừa có rủi ro overrun khi vòng CRC dài hơn một byte-time (88 µs ≈ 1 760 chu kỳ ở 20 MHz), vừa bị lỗi BI giả F1.

| **Yêu cầu trong Booting_Flow** | **Đáp ứng bởi core / wrapper** | **Kết luận** |
|:---|:---|:---|
| §2.1: 115 200 baud, chia 20 MHz cho 11 → 113 636 | {DLM,DLL} = 11, f = 20e6 / (16 × 11) | ✔ Tương thích, số liệu trùng khớp |
| §4.3: uart_init(FIXED_BAUD_DIVIDER) | 5 lệnh ghi thanh ghi (bước 1–5) | ✔ Hiện thực được |
| §5: bit/cờ polling RX-not-empty chưa xác nhận | LSR\[0\] (DR) tại offset 0x14 | ✔ Đóng open item |
| §4.3: uart_print("CRC FAIL") | Poll LSR\[5\] (THRE) trước khi ghi THR | ✔ Cần bổ sung vào pseudocode |
| §5: polling, không dùng ngắt | IER = 0x00 | ✔ Không phụ thuộc F4 |
| §1: single-shot, không ACK/retry | FIFO 16 byte làm vùng đệm | ✔ Khi FCR = 0x07; ⚠ nếu giữ FCR = 0x00 |

**Bảng 18. Đối chiếu yêu cầu Booting_Flow với core IP**

### 13.2 Diễn giải

> ***Diễn giải:** Đây là "công thức" để bootloader bật UART đúng cách: nạp tốc độ, chọn khung 8 bit, bật hàng đợi, rồi chờ từng byte. Mỗi bước đều có lý do lấy từ mã nguồn. Bật hàng đợi FIFO đặc biệt quan trọng: nó vừa tránh lỗi báo sai, vừa cho CPU thêm thời gian tính CRC mà không mất byte.*

*[figure not reproduced]*

**Hình 14. Lưu đồ khởi tạo và nhận ảnh qua UART0**

*Nguồn: diagrams/present/F14_boot_uart_flow.drawio*

## 14. Các phát hiện kỹ thuật và rủi ro

### 14.1 Lập luận

Các phát hiện được phân loại theo hai trục: **độ chắc chắn** (đọc thấy trực tiếp trong RTL, phụ thuộc cấu hình, hay cần mô phỏng xác nhận) và **mức ảnh hưởng** tới QSOC (tài liệu/hiệu năng, driver/tích hợp, boot).

| **ID** | **Phát hiện** | **Bằng chứng** | **Ảnh hưởng** | **Biện pháp** |
|:---|:---|:---|:---|:---|
| **F1** | Non-FIFO gán cứng LSR.BI = 1 cho mọi byte | obi_uart_rx.sv:462 | **Cao**: ROM kiểm tra lỗi sẽ báo sai; RLS irq với mỗi byte | Bắt buộc FCR = 0x07; báo lỗi upstream |
| **F2** | DLAB = 1 thì đọc 0x08–0x1C trả PSLVERR | obi_uart_register.sv:273–287 | TB: load fault nếu driver đọc LSR/LCR khi DLAB = 1; báo cáo V2.0 ghi sai | Firmware ghi LCR tuyệt đối; sửa Table 6-2 của V2.0 |
| **F3** | LCR\[2\] có thể đảo nghĩa stop bit ở TX | obi_uart_tx.sv:217–239 | Thấp: chậm khoảng 9 % | Mô phỏng TC-07; nếu đúng thì chọn LCR\[2\] phù hợp hoặc chấp nhận |
| **F4** | Ngắt RLS/MSTAT là xung 1 chu kỳ | obi_uart_interrupts.sv:49–66 | TB: PLIC có thể mất ngắt lỗi | Mô phỏng TC-08; firmware không dùng IER\[2\]/\[3\] |
| **F5** | DLL reset = 1 làm baudgen dừng | obi_uart_baudgen.sv:54–56, obi_uart_pkg.sv:200 | **Cao** nếu ROM quên nạp divisor | Bước 2 bắt buộc trong ROM (Hình 14) |
| **F6** | Chỉ giải mã addr\[4:2\], gây 512 alias trong slot | obi_uart_register.sv:58 | TB: lỗi lập trình không bị phát hiện | P_STRICT_DECODE = 1 trong wrapper |
| **F7** | SPR không hiện thực; ISR\[7:6\] luôn = 11 kể cả khi FIFO tắt | obi_uart_register.sv:265, obi_uart_interrupts.sv:99 | Thấp: driver 8250 tự dò loại UART có thể nhận sai | Cấu hình cố định kiểu 16550A trong driver |
| **F8** | QNSC_SoC.drawio.xml lệch HAS v1.3 (INTMAP ở APB_M15) | So sánh hai tài liệu | Thấp: gây hiểu nhầm khi review | Cập nhật bản vẽ SoC |
| **F9** | Bản vá DMA chưa vào build; DMA QSOC là mem2mem, chưa có handshake ngoại vi | Bender.yml, HAS DMA | TB: tính năng chưa dùng được | Để hở o_dma_tx_req/o_dma_rx_req ở v1 |

**Bảng 19. Danh sách phát hiện F1–F9 (TB = trung bình)**

Ba phát hiện F1, F2 và F5 **đã được khẳng định bằng đọc mã** và có biện pháp ở mức firmware hoặc wrapper, không cần sửa RTL upstream. Hai phát hiện F3 và F4 **chưa được kết luận** và được chuyển sang kế hoạch kiểm chứng (mục 15).

| **Độ chắc chắn \\ Ảnh hưởng** | **Tài liệu / hiệu năng** | **Driver / tích hợp** | **Boot** |
|:---|:---|:---|:---|
| Đọc thấy trực tiếp trong RTL | F7, F8 | F2, F6, F9 | **F1, F5** |
| Cần mô phỏng xác nhận | F3 | F4 | — |

**Bảng 20. Bản đồ rủi ro rút gọn (chi tiết ở Hình 15)**

### 14.2 Diễn giải

> ***Diễn giải:** Bản đồ rủi ro cho thấy: các vấn đề nghiêm trọng nhất (ô đỏ) đều đã biết chắc và đã có cách tránh đơn giản, là bật FIFO và nạp tốc độ baud trước. Các vấn đề còn nghi ngờ đều ở mức ảnh hưởng thấp hoặc trung bình, và sẽ được mô phỏng để trả lời dứt điểm.*

*[figure not reproduced]*

**Hình 15. Bản đồ phát hiện và rủi ro**

*Nguồn: diagrams/present/F15_findings_risk_map.drawio*

## 15. Kế hoạch kiểm chứng

### 15.1 Lập luận

Testbench đặt m_qnsc_wrap_apb_uart làm DUT và gồm các thành phần:

- APB master BFM, dùng lại apb_test.sv của pulp-platform/apb (deps/apb/src/apb_test.sv).

- Mô hình UART đối tác có thể chỉnh sai số baud ±2 % và tiêm lỗi PE, FE, break.

- Scoreboard so byte và cờ LSR/ISR.

- Monitor đo độ rộng xung o_int_uart.

- Coverage chéo LCR × FCR × IER.

Mỗi test case gắn với một phát hiện hoặc một yêu cầu boot:

| **TC** | **Mục tiêu** | **Tiêu chí đạt** | **Liên kết** |
|:---|:---|:---|:---|
| TC-01 | Giá trị reset | LSR = 0x60, ISR = 0xC1, DLL = 0x01, các thanh ghi khác = 0 | obi_uart_pkg.sv:189–201 |
| TC-02 | P_STRICT_DECODE | Truy cập offset ≥ 0x20 trong slot trả PSLVERR, không đổi thanh ghi | F6 |
| TC-03 | F2 | Đọc LSR khi DLAB = 1 trả PSLVERR; sau khi DLAB = 0 đọc được | F2 |
| TC-04 | Loopback | MCR\[4\] = 1, 8N1, D = 11: byte phát bằng byte thu | Mục 5 |
| TC-05 | Boot | Nhận 60 KiB liên tục, FIFO bật, không overrun, CRC khớp | Mục 13 |
| TC-06 | F1 | Non-FIFO: ghi nhận LSR\[4\] sau mỗi byte (tái hiện lỗi) | F1 |
| TC-07 | F3 | Đo số bit stop trên sout với LCR\[2\] = 0/1 | F3 |
| TC-08 | F4 | Tiêm PE/FE/break với IER\[2\] = 1, đo độ rộng o_int_uart và phản ứng của PLIC | F4 |
| TC-09 | Timeout | FIFO trigger 14, gửi 3 byte, chờ ngắt timeout (ISR = 0xCC) | Mục 10 |
| TC-10 | Dung sai baud | Đối tác lệch ±2 %, không có FE/PE | Mục 8 |

**Bảng 21. Danh sách test case**

### 15.2 Diễn giải

> ***Diễn giải:** Mỗi nghi vấn trong báo cáo đều có một bài kiểm tra riêng để trả lời "đúng" hoặc "sai". Bài quan trọng nhất là TC-05: giả lập nạp một ảnh 60 KiB như lúc boot thật, và yêu cầu không được mất byte nào.*

*[figure not reproduced]*

**Hình 16. Kiến trúc testbench**

*Nguồn: diagrams/present/F16_verification_plan.drawio*

## 16. Kết luận và câu hỏi cho phản biện

### 16.1 Kết luận

- \(1\) pulp-platform/apb_uart v0.2.3 là lựa chọn phù hợp cho QSOC. Nó thoả R1–R6, cho truy cập APB 0 wait-state và dùng bản đồ thanh ghi 16550A.

- \(2\) Research từ mã nguồn tìm thấy **9 phát hiện** mà báo cáo V2.0 chưa nêu hoặc nêu chưa đúng. Hai phát hiện ảnh hưởng tới boot (F1, F5) đã có biện pháp ở mức firmware.

- \(3\) Wrapper m_qnsc_wrap_apb_uart (qsoc_dma_changes/apb_uart_wrap.sv) **không sửa logic lõi** ngoài bản vá DMA đã có. Nó thêm bộ giải mã offset chặt, tie-off modem an toàn, định nghĩa giao tiếp IO MUX/PLIC/SCRC, đưa ra hai cổng yêu cầu DMA, và **đạt toàn bộ checklist §4.3 của QNSC RTL Design Naming Rule V1.0** tại biên wrapper.

- \(4\) Việc còn mở: lint và mô phỏng wrapper mới (chưa chạy), mô phỏng TC-07 (F3) và TC-08 (F4), cập nhật qsoc_dma_changes/apb_uart.sv theo module mới, cập nhật QNSC_SoC.drawio, và sửa Table 6-2 của báo cáo V2.0.

**⚠** *Wrapper mới chưa qua lint và mô phỏng. Mọi khẳng định về hành vi của wrapper trong báo cáo dựa trên đọc mã tĩnh và cần được xác nhận bằng TC-01…TC-05.*

### 16.2 Câu hỏi dự kiến từ phản biện và trả lời

| **Câu hỏi** | **Trả lời** |
|:---|:---|
| Vì sao không sửa lỗi F1 trực tiếp trong RTL? | Giữ mã trùng upstream để dễ nâng cấp và dễ truy nguồn. Lỗi tránh được hoàn toàn bằng FCR = 0x07. Lỗi sẽ được báo lên upstream; nếu upstream sửa thì chỉ cần nâng tag. |
| Vì sao wrapper dùng cổng APB rời thay vì struct? | QNSC Naming Rule §3.3 và §4.3 yêu cầu cổng i_bus_apb\_\<signal\> và chuẩn hoá IP bên thứ ba tại biên wrapper. Struct PULP chỉ còn bên trong; tên trường giữ nguyên từ vựng APB chuẩn (paddr, psel…). |
| Wrapper có làm tăng trễ truy cập? | Không. Bộ so sánh 9 bit là logic tổ hợp trên đường psel. Truyền vẫn 2 chu kỳ. Ở 20 MHz, đường này không đáng kể về timing. |
| Tại sao chọn 115 200 mà không chọn 625 000 (chính xác 0 %)? | Tốc độ được nung cứng trong ROM. 625 000 không phải tốc độ chuẩn, nên adapter phía host không hỗ trợ sẽ khiến chip không thể boot (HAS §13). |
| Tại sao không dùng uDMA UART? | Nó vi phạm R4: kéo theo udma_core và cầu nối L2. Đây là phương án cho phiên bản sau, khi cần truyền khối lớn không qua CPU. |
| Nếu IO MUX cấp 0 vào RX khi không chọn chân? | Bộ thu thấy break liên tục, sinh FE/BI và có thể ngắt liên tục. Vì vậy báo cáo ghi thành **yêu cầu bắt buộc** đối với chủ khối IO MUX: idle phải bằng 1. |
| Modem tie 1 hay 0? | Tie 1. Nó trùng giá trị reset của FF đồng bộ modem (obi_uart_modem.sv:110–113), nên không sinh delta giả sau reset, và TX không phụ thuộc CTS. |

**Bảng 22. Câu hỏi phản biện dự kiến**

## Phụ lục A. Danh mục hình

| **Hình** | **Nội dung** | **File draw.io (diagrams/present/)** |
|:---|:---|:---|
| 1 | Vị trí UART trong QSOC | F01_qsoc_uart_context.drawio |
| 2 | Lưu đồ quy trình research | F02_research_flow.drawio |
| 3 | Ma trận lựa chọn IP | F03_ip_selection.drawio |
| 4 | Phân cấp IP | F04_ip_hierarchy.drawio |
| 5 | Vi kiến trúc obi_uart | F05_obi_uart_microarch.drawio |
| 6 | FSM + giản đồ APB → OBI | F06_apb_to_obi_timing.drawio |
| 7 | Giải mã địa chỉ và DLAB | F07_register_decode.drawio |
| 8 | Baudgen và lấy mẫu | F08_baudgen_sampling.drawio |
| 9 | FSM TX | F09_tx_fsm.drawio |
| 10 | FSM RX | F10_rx_fsm.drawio |
| 11 | Khối ngắt | F11_interrupt_priority.drawio |
| 12 | Wrapper m_qnsc_wrap_apb_uart | F12_qsoc_uart_wrap_block.drawio |
| 13 | Ánh xạ tín hiệu | F13_wrapper_signal_map.drawio |
| 14 | Lưu đồ boot UART (mục 13) | F14_boot_uart_flow.drawio |
| 15 | Bản đồ rủi ro (mục 14) | F15_findings_risk_map.drawio |
| 16 | Kiến trúc testbench (mục 15) | F16_verification_plan.drawio |
| 17 | Chuẩn hoá tên theo Naming Rule (mục 12.4) | F17_naming_compliance.drawio |
| 18-1 … 18-5 | Sơ đồ chi tiết wrapper, 5 trang (mục 12.5) | F18_uart_wrap_detailed.drawio |

**Bảng 23. Danh mục hình**

Số hình giữ đúng số đã in trong ảnh PNG và trong present.md (Hình 1–18), nên Hình 17 (mục 12.4) xuất hiện trước Hình 14 (mục 13).

Tất cả file .drawio đều là XML không nén, mở trực tiếp được bằng draw.io desktop hoặc app.diagrams.net. Lệnh xuất lại PNG:

"C:/Program Files/draw.io/draw.io.exe" -x -f png -s 1.5 -b 10 -o png/F01_qsoc_uart_context.png F01_qsoc_uart_context.drawio

Script sinh toàn bộ hình: diagrams/present/gen_diagrams.py và diagrams/present/gen_uart_wrap_detailed.py.

## Phụ lục B. Tài liệu và file tham chiếu

| **Loại** | **Đường dẫn** |
|:---|:---|
| RTL wrapper upstream | src/apb_uart.sv, src/apb_uart_wrap.sv, src/reg_uart_wrap.sv |
| RTL wrapper QNSC | qsoc_dma_changes/apb_uart_wrap.sv (module m_qnsc_wrap_apb_uart) |
| Quy tắc đặt tên | naming_rule/naming_rule/MCU_guide_ws-main/MCU_guide_ws-main/DM/RULES/FE/Release/QNSC_RTL_Design_Naming_Rule.pdf |
| RTL core | deps/obi_peripherals/hw/obi_uart/obi_uart\*.sv |
| Bridge | deps/obi/src/apb_to_obi.sv |
| Bản vá DMA (chưa build) | qsoc_dma_changes/\*.sv |
| Quản lý phụ thuộc | Bender.yml, CHANGELOG.md |
| Kiến trúc hệ thống | doc_research/00_HAS/QSOC_HAS_Report_EN_v1 3.docx (Table 5-3, 5-4, 8-1, 8-2, 13-5) |
| Sơ đồ SoC | VLSI_DeepTrainnig/QNSC_SoC.drawio.xml, VLSI_DeepTrainnig/qnsc_soc.drawio |
| Boot flow | Booting_Flow_NguyenHaoNam.docx (§2.1, §4.3, §5) |
| Báo cáo trước | doc_research/06_UART_apb_uart/APB_UART_CoreIP_Research_Report_v2.0.docx |
| Bản trình bày gốc | present.md |

**Bảng 24. Tài liệu và file tham chiếu**

## Phụ lục C. Ma trận truy vết phát hiện → minh chứng → kiểm chứng

Bảng này cho phép người phản biện đi từ mỗi kết luận tới đúng đoạn mã đã trích trong báo cáo và tới bài kiểm tra sẽ xác nhận nó.

| **ID** | **Mục chứa minh chứng** | **File : dòng** | **Trạng thái** | **Test case** |
|:---|:---|:---|:---|:---|
| F1 | 10.1 | obi_uart_rx.sv:460–463 | Khẳng định (đọc mã) | TC-06, TC-05 |
| F2 | 7.1 | obi_uart_register.sv:273–287 | Khẳng định (đọc mã) | TC-03 |
| F3 | 9.1 | obi_uart_tx.sv:217–239 | Nghi vấn — cần mô phỏng | TC-07 |
| F4 | 11.1 | obi_uart_interrupts.sv:11, 49–66 | Nghi vấn — cần mô phỏng | TC-08 |
| F5 | 8.1 | obi_uart_baudgen.sv:54–56, obi_uart_pkg.sv:200 | Khẳng định (đọc mã) | TC-01, TC-05 |
| F6 | 7.1 | obi_uart_register.sv:58 | Khẳng định; khoá bởi wrapper | TC-02 |
| F7 | 14.1 | obi_uart_register.sv:265, obi_uart_interrupts.sv:99 | Khẳng định (đọc mã) | TC-01 |
| F8 | 1.1 | HAS v1.3 ↔ QNSC_SoC.drawio.xml | Khẳng định (so tài liệu) | Review tài liệu |
| F9 | 4.1, 12.1 | Bender.yml:17–20, qsoc_dma_changes/obi_uart.sv:169 | Khẳng định (đọc mã) | — |
| Boot baud | 8.1, 13.1 | obi_uart_baudgen.sv:54–104 | Khẳng định, trùng Booting_Flow §2.1 | TC-04, TC-10 |
| Polling DR | 13.1 | obi_uart_rx.sv:421, obi_uart_pkg.sv:132–141 | Khẳng định (đọc mã) | TC-05 |

**Bảng 25. Ma trận truy vết**
