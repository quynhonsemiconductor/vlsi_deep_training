# Thuyết trình SYSDBG — bản đọc

**Khớp tài liệu:** `QNSC_SYSDBG_MAS` V3.0 · **Ngày:** 2026-09-24

## 1. SYSDBG là gì

`SYSDBG` là debugger của QSOC: host nói chuyện với nó qua JTAG TAP.
Bên trong có một AXI4 manager trên `AXI_S0` để đọc/ghi bộ nhớ, và một 4-phase
handshake nối hai clock domain `TCK` và `i_clk_cpu`.
Nó điều khiển CPU bằng hai đường: `o_cpu_debug_req` để halt Ibex, và `o_cpu_hold`
để giữ CPU trong reset khi pad `DBG_EN` = 1.
Nó không có memory-mapped register, không reset chip, không gate clock.

## 2. Flow end-to-end

**A. Debug boot (`DBG_EN` = 1)**

1. **Board / host.** Pad `DBG_EN` được đặt = 1 (board có pull-down, mặc định là 0).
2. **Power-on.** `i_rst_n_por` reset cả ba domain của `SYSDBG`. `o_cpu_hold` = 1 vì
   nó là flip-flop reset 1. DR `CPUHOLD` cũng reset 1.
3. **SYSDBG, system domain.** Synchronise `i_dbg_en`, capture **một lần** sau
   `SyncStages` + 1 cycle kể từ khi `i_rst_n_por` nhả. Kết quả là `o_dbg_en` = 1,
   giữ đến power-on reset kế tiếp.
4. **`o_dbg_en` = 1 đi ra ba chỗ.** Boot address mux chọn `boot_addr_i` =
   `0x2000_1000`. IO MUX ép 5 pad JTAG về chức năng JTAG. Và `o_cpu_hold` từ giờ đi theo
   `CPUHOLD` (đang = 1).
5. **SCRC.** Nhả reset cho bus, ROM, RAM, peripheral. CPU reset = SCRC CPU reset OR
   `o_cpu_hold`, qua CPU reset synchroniser, nên **Ibex vẫn nằm trong reset**.
6. **Host/JTAG adapter → SYSDBG → S_BUS → ISRAM.** Host ghi debug window
   `0x2000_0000`–`0x2000_0FFF`, từng word một. Mỗi word là một write:
   IR = `ADDR`, DR = {1, A} → IR = `DATA`, DR = D → Update-DR bật `write_req` →
   CDC → AXI manager chạy AW/W/B trên `AXI_S0` → `S_BUS` → `ISRAM`. Host scan
   `STATUS` đến khi `busy` = 0 và kiểm tra `resp` = `00`.
7. **Host.** Ghi program image từ `0x2000_1000`, cùng cách như bước 6.
8. **Host (tuỳ chọn).** `CPUDBG` = 1. `dbgreq` qua synchroniser ra `o_cpu_debug_req`
   = 1, vào `debug_req_i` của Ibex.
9. **Host.** `CPUHOLD` = 0 → `cpu_hold` qua synchroniser → `o_cpu_hold` = 0 → SCRC
   nhả `rst_ni` của Ibex. Ibex chạy từ `0x2000_1080` (boot address + `0x80`).
   Nếu đã làm bước 8, core halt ngay trước lệnh đầu, `dpc` = `0x2000_1080`.
10. **Halt (Ibex + debug window).** Khi `debug_req` lên, Ibex lưu PC vào `dpc`, nhảy
    tới `DmHaltAddr` = `0x2000_0800`. Code trong window lưu `s0`, `s1` vào
    `dscratch0/1`, ghi `HALTED` = 1, rồi vào dispatch loop. Host đọc `HALTED` qua
    `SYSDBG` để xác nhận đã halt.
11. **Đọc một thanh ghi CPU, ví dụ `dpc`.** Host ghi một sequence vào đầu window
    (`csrr s1, dpc` → ghi `DATA` → `CMD` = 0 → `j LOOP`), ghi `EXC` = 0, rồi
    `CMD` = 1. Loop thấy `CMD` ≠ 0 thì nhảy vào sequence. Host poll `CMD` đến khi
    = 0, rồi đọc `EXC` và `DATA`. Mỗi lần "ghi/đọc" ở đây là một transaction qua
    `SYSDBG` như bước 6. (Địa chỉ flag nằm trong `_DECISIONS`, "Debug window code".)
12. **Resume.** Host ghi `CPUDBG` = 0 **trước**, rồi mới ghi `RESUME` = 1 vào window.
    Loop xoá `RESUME`, `HALTED`, khôi phục `s0`, `s1`, chạy `dret` → Ibex về `dpc`.
13. **Chạy lại.** `CPUHOLD` = 1 → sửa image → `CPUHOLD` = 0. `ISRAM` không bị xoá.

**B. Normal boot (`DBG_EN` = 0), attach sau**

1. Power-on và capture như bước 2–3 ở A, nhưng `o_dbg_en` = 0. Từ lúc capture,
   `o_cpu_hold` = 0 vĩnh viễn; `CPUHOLD` không còn tác dụng.
2. `boot_addr_i` = `0x0000_0000`. SCRC nhả CPU, Ibex chạy ROM bootloader từ
   `0x0000_0080`. Bootloader nạp image rồi nhảy tới `0x2000_1080`.
3. Chân JTAG do IO MUX register quyết định, mặc định là JTAG.
4. **Attach.** Host ghi debug window trong lúc CPU đang chạy (AXI manager truy cập
   được cả khi CPU chạy). Phải xong trước lần halt đầu tiên.
5. Halt, đọc thanh ghi, resume: y như bước 10–12 ở A.
6. Giới hạn: firmware có thể remap chân JTAG và làm mất kết nối. Khi đó dùng debug boot.

**C. Watchdog bite hoặc software reset**

1. **SCRC** reset domain `S_BUS` (`i_rst_n_sysbus`) và reset CPU.
2. **SYSDBG:** chỉ AXI domain bị reset. TCK domain và system domain chỉ nhận
   `i_rst_n_por`, nên `o_dbg_en`, `dbgreq`, `cpu_hold`, IR, các DR đều giữ nguyên.
3. Nếu đang có transaction dở, `req` vẫn còn giữ bên TCK. Khi `i_rst_n_sysbus` nhả,
   AXI manager thấy cạnh lên và **issue lại**. Host chỉ thấy `busy` lâu hơn.
4. **ISRAM** không có reset, nên window và image còn nguyên.
5. **CPU:** theo SCRC, rồi theo 7.1. Debug boot với `CPUHOLD` = 0 → chạy lại từ
   `0x2000_1080`. `CPUHOLD` = 1 → vẫn bị giữ. Normal boot → chạy lại bootloader.
6. Điều kiện: `i_rst_n_por` phải là power-on **only** (xem Table 11-1).

Riêng `i_jtag_trst_n`: chỉ reset TCK domain, `dbgreq` = 0, `cpu_hold` = 1. Ở debug
boot, CPU bị giữ lại.

| IP liên quan | SYSDBG cần gì từ IP đó |
|---|---|
| Host / JTAG adapter | Chạy đúng sequence 7.4, ghi debug window, giữ thứ tự `CPUDBG` = 0 rồi `RESUME` = 1 |
| Top / pad owner | Pad `DBG_EN` trên một no-connect pad, pull-down trên board |
| SCRC | `i_rst_n_por` chỉ từ power-on; OR `o_cpu_hold` vào CPU reset **trước** synchroniser |
| S_BUS | `AXI_S0` nối thẳng, AXI4, ID width 5; luôn trả response (`DECERR` cho địa chỉ lạ) |
| ISRAM (RAM owner) | Array không reset, không clear-on-reset |
| Ibex (CPU owner) | Boot address mux theo `o_dbg_en`; `DmHaltAddr` = `0x2000_0800`, `DmExceptionAddr` = `0x2000_0810`; `fetch_enable_i` tied on |
| IO MUX | Ép 5 pad JTAG về JTAG khi `o_dbg_en` = 1 |
| Firmware | Link image ở `0x2000_1000`, entry `0x2000_1080`; không đặt gì vào window |

## 3. Giải thích từng hình

### Figure 3-1. SYSDBG block diagram

Hình này trả lời: bên trong `SYSDBG` có gì, FSM ở đâu, CDC ở đâu, và ba domain
tách nhau thế nào.

| Block | Là gì | Nối với ai / tín hiệu |
|---|---|---|
| JTAG pads | Chân từ host: `TCK`, `TMS`, `TDI`, `TDO`, `TRST_N` | `TMS` → TAP FSM, `TDI` → IR/DR, nhận `TDO` từ TDO mux |
| DBG_EN pad | Chân chọn boot mode | `i_dbg_en` → DBG_EN 2FF + capture |
| TAP FSM 16 states | State machine IEEE 1149.1, chạy trên `TCK` | Nhận `TMS`, ra control signals |
| control signals | Decode state thành capture / shift / update | Điều khiển khối DR |
| IR 4 bit | Instruction register | `select` chọn DR nào |
| ADDR · DATA · STATUS · CPUDBG · CPUHOLD · IDCODE · BYPASS | Bảy data register | Shift từ `TDI`; ra TDO mux; `addr`/`wdata` sang CDC; nhận `rdata`/`resp` từ CDC |
| TDO mux | Chọn bit ra, flop cạnh xuống | → `TDO` |
| read_req · write_req · busy | Phía TCK của handshake (in đậm) | Update-DR set `req`; `req` → CDC |
| CDC | Chỗ duy nhất tín hiệu đổi domain (in đậm) | Liệt kê mọi tín hiệu cross: `req`/`ack` 2FF, `addr`/`wdata`/`rdata`/`resp` dùng `set_max_delay` |
| 2FF + edge | Synchroniser + phát hiện cạnh lên | Ra `set_ar` / `set_aw` cho AXI manager |
| AXI manager | Chạy AR/R hoặc AW/W/B | AXI4 → `S_BUS AXI_S0`; R, B → rdata_reg |
| rdata_reg · resp_reg · read_ack · write_ack | Kết quả và ack phía AXI | → CDC → về TCK |
| S_BUS AXI_S0 | Cổng slave của bus hệ thống | Nhận AXI4 |
| dbgreq · cpu_hold 2FF | Synchroniser TCK → system | → khối output |
| DBG_EN 2FF + capture | Synchronise và chốt `DBG_EN` một lần | → khối output |
| o_cpu_debug_req · o_dbg_en · o_cpu_hold | Flop output của system domain | `debug_req` → Ibex; còn lại → SCRC, boot mux, IO MUX |
| Ibex CPU | Core RISC-V | Nhận `debug_req` |
| SCRC · boot mux · IO MUX | Ba nơi nhận `o_cpu_hold` và `o_dbg_en` | Xem Figure 7-1 |

Cách đọc:

1. Ba khung nét đứt là ba domain: TCK (`i_jtag_tck`, reset TRST_N & POR), AXI
   (`i_clk_cpu`, `i_rst_n_sysbus`), system (`i_clk_cpu`, `i_rst_n_por`).
2. Trái sang phải là đường lệnh: `TMS` lái TAP FSM, `TDI` shift vào IR hoặc DR.
3. Update-DR của `ADDR`/`DATA` set `read_req`/`write_req` → qua CDC → 2FF + edge →
   AXI manager → `S_BUS`.
4. Đường về: R/B → `rdata_reg`, `resp_reg`, `ack` → CDC → DR (`rdata`, `resp`) và `busy`.
5. `dbgreq`, `cpu_hold` đi đường riêng qua CDC xuống system domain, rồi ra Ibex và SCRC.
6. `DBG_EN` pad đi thẳng vào system domain, không qua TCK.

**Hỏi:** FSM ở đâu, CDC ở đâu?
**Đáp:** FSM là TAP FSM trong TCK domain. AXI manager là các flop valid/ready
set/clear theo Table 7-3. CDC là khối giữa; mọi tín hiệu cross ghi trong đó và trong Table 7-4.

**Hỏi:** AXI domain và system domain cùng `i_clk_cpu`, sao tách làm hai?
**Đáp:** Khác reset. AXI domain reset theo `S_BUS`; system domain chỉ theo power-on,
nên `o_dbg_en` và hold sống qua watchdog (mục 2, phần C).

**Hỏi:** Sao TCK domain reset bằng cả TRST và POR?
**Đáp:** Để `CPUHOLD` = 1 ngay từ power-on, kể cả khi adapter chưa cắm hay không lái TRST.

**Hỏi:** Sao TDO ra ở cạnh xuống?
**Đáp:** IEEE 1149.1 quy định vậy: TDO đổi ở cạnh xuống để host lấy mẫu ở cạnh lên.

### Figure 7-1. Debug boot wiring

Hình này trả lời: `SYSDBG` nối với phần còn lại của chip thế nào để làm debug boot.

| Block | Là gì | Nối với ai / tín hiệu |
|---|---|---|
| DBG_EN pad | Chân chọn mode | `i_dbg_en` → SYSDBG |
| JTAG pads | Chân host | JTAG → SYSDBG |
| SYSDBG | IP này | Ra `o_dbg_en`, `o_cpu_hold`, `debug_req`, AXI4 |
| IO MUX | Mux chân | `o_dbg_en` = 1 → 5 pad JTAG = JTAG |
| boot_addr mux | Mux 2:1 | `o_dbg_en`: 0 → `0x0000_0000`, 1 → `0x2000_1000`; ra `boot_addr_i` |
| CPU reset synchroniser | Nằm trong SCRC | `o_cpu_hold` OR SCRC CPU reset → `rst_ni` |
| SCRC | Clock/reset controller | CPU reset → synchroniser |
| Ibex CPU | Core | Nhận `debug_req`, `boot_addr_i`, `rst_ni`; là manager trên `S_BUS` |
| S_BUS AXI_S0 | Bus hệ thống, cổng của SYSDBG | Nhận AXI4 từ SYSDBG; → ISRAM |
| ISRAM | RAM lệnh | Chứa debug window và image |

Cách đọc (theo thứ tự thời gian):

1. `i_dbg_en` vào SYSDBG, ra `o_dbg_en`.
2. `o_dbg_en` = 1 ép chân JTAG và chọn boot address `ISRAM`.
3. `o_cpu_hold` = 1 giữ `rst_ni` của Ibex thấp, dù SCRC đã nhả.
4. Host ghi window + image theo đường AXI4 → `S_BUS` → `ISRAM`.
5. `o_cpu_hold` = 0 → Ibex chạy từ `ISRAM`. `debug_req` (dây trên cùng) dùng để halt.

**Hỏi:** Sao OR `o_cpu_hold` **trước** synchroniser mà không OR sau?
**Đáp:** OR sau synchroniser có thể glitch khi SCRC nhả reset đúng cycle host set hold.
Qua synchroniser thì release luôn sạch và đồng bộ.

**Hỏi:** Không có boot_addr mux thì sao?
**Đáp:** CPU sẽ chạy ROM bootloader, ngồi chờ UART0, không bao giờ tới image đã nạp.

**Hỏi:** Sao không giữ CPU bằng `fetch_enable_i`?
**Đáp:** Đã có một cơ chế giữ là reset. Thêm hold thứ hai thì lại cần một đường release riêng.

**Hỏi:** Sao IO MUX phải ép chân?
**Đáp:** Để firmware remap chân không làm hỏng debug boot. Một cổng logic là đủ.

### Figure 7-2. Read handshake

Hình này trả lời: một lệnh read đi qua CDC thế nào, flop nào set, flop nào clear.

| Block | Là gì | Nối với ai / tín hiệu |
|---|---|---|
| Update-DR ADDR | Điều kiện bắt đầu read: `addr[32]` = 0, không busy | `set` → read_req_reg |
| read_req_reg | Flop `req` phía TCK (in đậm) | `read_req` → 2FF phía AXI |
| 2FF · dly (AXI) | Synchroniser + một flop delay | → set_ar |
| set_ar | `sync & !dly`: cạnh lên của `req` | → AR · R |
| AR · R | AXI read: `arvalid`, `rready` | `rvalid` → rdata_reg |
| araddr | Địa chỉ AXI | Lấy thẳng `addr_reg[31:0]`, `set_max_delay` 1 AXI clock |
| rdata_reg · resp_reg | Chốt `rdata`, `rresp` | → read_ack_reg; → Data/Response register |
| read_ack_reg | `dly & !rready` (in đậm) | `read_ack` → 2FF phía TCK |
| 2FF · dly (TCK) | Synchroniser + delay | `rising edge` → Data/Response register; `clear` → read_req_reg |
| Data register · Response register | `rdata_hold`, `resp` phía TCK | Nhận `rdata`/`resp`, `set_max_delay` 1 TCK |
| addr_reg[31:0] | Địa chỉ phía TCK | → `araddr` |
| Khung write (dưới cùng) | Write giống hệt, chỉ khác điểm bắt đầu | Update-DR `DATA`, `addr[32]` = 1; AW W B; `write_req`/`write_ack` |

Cách đọc (đúng sáu pha của 7.6):

1. Update-DR `ADDR` set `read_req`.
2. `read_req` qua 2FF; `set_ar` là cạnh lên → AXI manager phát `arvalid`, `araddr`.
3. `rvalid` về → chốt `rdata_reg`, `resp_reg`, hạ `rready` → `read_ack` lên và giữ.
4. Phía TCK thấy cạnh lên của `ack` → chốt data/response → `clear` `read_req`.
5. Phía AXI thấy `req` xuống → `ack` xuống.
6. Phía TCK thấy `ack` xuống → hết `busy`.

**Hỏi:** `addr`, `rdata` không qua synchroniser, có an toàn không?
**Đáp:** An toàn vì chúng đứng yên suốt cửa sổ handshake. `busy` chặn Update-DR nên
`addr_reg` không đổi; `set_max_delay` đảm bảo chúng tới trước khi `req`/`ack` được thấy.

**Hỏi:** Sao gọi là 4-phase?
**Đáp:** `req` lên, `ack` lên, `req` xuống, `ack` xuống. Nhờ vậy `busy` chỉ đơn giản là
"handshake chưa về idle".

**Hỏi:** `TCK` dừng giữa chừng thì sao?
**Đáp:** Handshake theo mức, không theo thời gian, nên nó chỉ đứng chờ. Verification
có test `TCK` dừng 10,000 cycle giữa handshake.

## 4. Giải thích từng bảng

### Revision history (bảng không đánh số)

Một dòng: chỉ có V3.0, 2026-09-23, viết lại theo reference design của thầy.
Lý do và các bản cũ nằm trong `QNSC_SYSDBG_DECISIONS.md`.

### Table 4-1. Upstream IP used

- **Để làm gì:** liệt kê IP mua/lấy từ ngoài.
- **Cột:** From (nguồn), Module, Commit, Licence.
- **Dòng đáng chỉ:** toàn `--`. `SYSDBG` tự viết, không instantiate gì.

**Hỏi:** Sao không dùng RISC-V Debug Module chuẩn?
**Đáp:** Thiết kế theo reference của thầy: JTAG data register + AXI4 manager. MAS
không dùng DM nên bảng trống.

### Table 5-1. SYSDBG interface

- **Để làm gì:** mọi port của `m_qnsc_sysdbg`.
- **Cột:** Signal, Dir (in/out), Width, Description.
- **Dòng đáng chỉ:**
  - `i_clk_cpu` 20 MHz, dùng cho cả AXI và system domain.
  - `i_rst_n_por` và `i_rst_n_sysbus`: hai reset khác nhau, xem mục 2 phần C.
  - `i_jtag_tck`: asynchronous, có thể dừng bất cứ lúc nào.
  - `o_jtag_tdo_oe` = 1 chỉ ở Shift-IR, Shift-DR.
  - `o_cpu_hold`: từ flip-flop, reset 1, vào CPU reset synchroniser của SCRC.
  - `o_cpu_debug_req`: mức, từ flip-flop.
  - `o_bus_axi_araddr/awaddr` có `[1:0]` = 0: chỉ word.

**Hỏi:** Sao `o_cpu_hold` phải ra từ flip-flop?
**Đáp:** Nó là OR của ba term cùng đổi trong một cycle lúc capture `DBG_EN`. Nếu là
tổ hợp, nó có thể glitch xuống 0 và nhả reset CPU trong chốc lát.

**Hỏi:** AXI4 còn nhiều tín hiệu nữa đâu?
**Đáp:** Là hằng số hoặc input không dùng, liệt kê ở Table 10-1.

### Table 5-2. SYSDBG parameters

- **Để làm gì:** các parameter lúc elaborate.
- **Cột:** Parameter, Default, Meaning.
- **Dòng đáng chỉ:** `IdcodeValue` = `0x0515_3001` (part `0x5153` = "QS", bit 0 = 1);
  `AxiIdWidth` = 5 theo `S_BUS`; `SyncStages` = 2.

**Hỏi:** Sao `AxiIdWidth` = 5, hình của thầy ghi 4?
**Đáp:** 5 là ID width cổng slave của `S_BUS` trong HAS. Đây là fact của QSOC.

**Hỏi:** `SyncStages` ảnh hưởng gì ngoài CDC?
**Đáp:** Thời điểm capture `DBG_EN`: `SyncStages` + 1 cycle sau khi POR nhả.

### Table 6-1. JTAG instructions and data registers

- **Để làm gì:** đây là "register map" của `SYSDBG`, vì không có memory-mapped register.
- **Cột:** IR (mã 4 bit), Name, Bits (độ dài DR), Capture-DR loads (giá trị host đọc
  ra), Update-DR does (hành động khi scan xong), Reset.
- **Dòng đáng chỉ:**
  - `ADDR` 33 bit: bit 32 là chiều (0 read, 1 write). Update-DR với bit 32 = 0 bắt đầu read.
  - `DATA` 32 bit: capture là data read gần nhất; Update-DR khi `addr_reg[32]` = 1 bắt đầu write.
  - `STATUS` = {`busy`, `resp[1:0]`}. `resp`: `00` OKAY, `10` SLVERR, `11` DECERR.
  - `CPUDBG` → `dbgreq`, reset 0. `CPUHOLD` → `cpu_hold`, **reset 1**.
  - Mã không dùng hoạt động như `BYPASS`.

**Hỏi:** Sao read bắt đầu ở `ADDR`, write lại bắt đầu ở `DATA`?
**Đáp:** Read chỉ cần địa chỉ. Write cần cả data, nên phải đợi `DATA` được nạp.

**Hỏi:** Sao `CPUDBG` là `0111` chứ không phải `1110` như hình của thầy?
**Đáp:** `1110` đã là mã `IDCODE`, dùng lại sẽ đụng nhau.

**Hỏi:** Sao mã lạ lại là `BYPASS` chứ không phải X?
**Đáp:** IEEE 1149.1 yêu cầu vậy. Capture-IR nạp `0001`, Test-Logic-Reset nạp `IDCODE`, cũng theo chuẩn.

### Table 7-1. Effect of DBG_EN

- **Để làm gì:** so sánh hai boot mode trên bốn điểm.
- **Cột:** hàng tiêu chí, cột `DBG_EN` = 0 (normal boot), cột `DBG_EN` = 1 (debug boot).
- **Dòng đáng chỉ:** CPU leaves reset (thêm điều kiện `CPUHOLD` = 0); `boot_addr_i`
  (ROM hay `ISRAM`); first instruction (`0x0000_0080` hay `0x2000_1080`);
  JTAG pins (IO MUX register hay forced).

**Hỏi:** Sao lệnh đầu lệch `0x80` so với boot address?
**Đáp:** Ibex nhảy tới `boot_addr_i` + `0x80` khi ra reset. 128 byte đầu là vector table.

**Hỏi:** Sao cần pin ngoài, không dùng một register?
**Đáp:** Mode phải biết từ t = 0, trước khi host kịp scan. Register reset "hold" thì
chip không boot nếu không có probe; reset "run" thì CPU đã chạy trước khi host kịp ghi.

### Table 7-2. What each reset does

- **Để làm gì:** mỗi reset chạm tới domain nào.
- **Cột:** Event, TCK domain, AXI domain, System domain, CPU.
- **Dòng đáng chỉ:** Power-on reset tất cả. Watchdog/software chỉ reset AXI domain, request
  còn giữ được issue lại (mục 2 phần C). `i_jtag_trst_n` chỉ reset TCK domain.

**Hỏi:** Watchdog cắn giữa lúc host đang nạp image thì sao?
**Đáp:** Trong debug boot, lúc nạp CPU đang bị hold và watchdog tắt, nên chỉ có mất
nguồn mới reset được giữa chừng.

**Hỏi:** Issue lại một write có hại không?
**Đáp:** Không, vì đó là một word đọc/ghi đơn, làm lại cho cùng kết quả.

### Table 7-3. AXI manager behaviour

- **Để làm gì:** AXI manager làm gì ở mỗi sự kiện, cho read và write.
- **Cột:** Event, Read, Write.
- **Dòng đáng chỉ:**
  - `set_ar`/`set_aw`: bật tất cả valid/ready cùng lúc, lấy `addr_reg`, `wdata_reg`.
  - Mỗi handshake xong thì hạ valid/ready tương ứng.
  - Acknowledge: `ack` = `req` delayed AND NOT `rready` (hoặc `bready`).

**Hỏi:** Vì sao `ack` dùng `!rready`?
**Đáp:** `rready` chỉ về 0 khi R handshake xong. Nên `ack` lên đúng lúc data đã chốt vào `rdata_reg`.

**Hỏi:** Có hỗ trợ outstanding hay burst không?
**Đáp:** Không. Tối đa một transaction, một beat.

### Table 7-4. Crossing signals and constraints

- **Để làm gì:** danh sách đầy đủ tín hiệu cross domain, cách cross và constraint.
  CDC lint chỉ được thấy đúng các tín hiệu này.
- **Cột:** Signal, Direction, How it crosses, Constraint.
- **Dòng đáng chỉ:**
  - `req`/`ack`: `SyncStages` flop + một flop delay để lấy cạnh.
  - `addr_reg`, `wdata_reg`, `rdata_reg`, `resp_reg`: không synchroniser, chỉ
    `set_max_delay -datapath_only`, an toàn vì đứng yên trong cửa sổ handshake.
  - `dbgreq`, `cpu_hold`: TCK → system, chỉ `SyncStages` flop.

**Hỏi:** Sao `set_max_delay` một chu kỳ clock đích?
**Đáp:** Để data bus tới nơi trước khi tín hiệu control qua 2FF được bên kia thấy.

**Hỏi:** `dbgreq` qua 2FF thì có mất xung không?
**Đáp:** Không có xung. `dbgreq` và `cpu_hold` là mức do host giữ.

### Table 7-5. Debug window layout

- **Để làm gì:** 4 KiB đầu `ISRAM` chia ra sao.
- **Cột:** Address, Content.
- **Dòng đáng chỉ:** `0x2000_0000`–`0x07FF`: sequence và flag (`RESUME`, `HALTED`),
  do host ghi/đọc. `0x2000_0800` `DmHaltAddr`: entry mỗi lần halt.
  `0x2000_0810` `DmExceptionAddr`: exception trong Debug Mode. `0x0820`–`0x0FFF`: dispatch loop.

**Hỏi:** Ai nạp 4 KiB này, và khi nào?
**Đáp:** Host, qua JTAG. Debug boot: lúc CPU đang hold. Normal boot: trước lần halt
đầu. Firmware không đặt gì ở đây.

**Hỏi:** Sao code trong window cần `dscratch0/1`?
**Đáp:** Loop cần `s0`, `s1` để làm việc. Ibex chỉ có hai scratch CSR, nên lưu hai
thanh ghi đó vào đấy, `dret` trước thì khôi phục.

**Hỏi:** Sao không dùng port `debug_mode` để biết đã halt?
**Đáp:** `ibex_top` không export nó, và không được sửa RTL vendored. Code window đã
chạy mỗi lần halt nên tự ghi `HALTED`.

### Table 9-1. Functions this block does not provide

- **Để làm gì:** chặn trước câu hỏi "cái này ai làm?".
- **Cột:** Function, Where it lives.
- **Dòng đáng chỉ:** không reset chip (`o_cpu_hold` chỉ giữ CPU); không clock control;
  không byte/halfword, không burst; không debug ROM, program buffer (thay bằng window);
  `dret`, stepping, `ebreak` là của Ibex, không hardware trigger (`DbgTriggerEn = 0`).

**Hỏi:** Không có hardware trigger thì debug bootloader từ lệnh đầu thế nào?
**Đáp:** Debug boot, halt trước lệnh đầu, dùng sequence ghi `dpc` = `0x0000_0080`,
rồi single-step (`dcsr.step`) hoặc resume.

**Hỏi:** Muốn ghi một byte thì sao?
**Đáp:** Host đọc word, sửa byte, ghi lại word (read-modify-write).

### Table 10-1. Tie-offs

- **Để làm gì:** giá trị cố định cho các tín hiệu AXI4 không dùng.
- **Cột:** Port, Tied to, Why.
- **Dòng đáng chỉ:** `len` = 0 và `wlast` = 1 (một beat); `size` = `3'b010`, `wstrb` =
  `4'b1111` (word); `burst` = INCR; ID = 0; `rid`, `rlast`, `bid` bỏ qua.

**Hỏi:** Một beat thì burst type có nghĩa gì?
**Đáp:** Không ảnh hưởng. MAS chọn INCR vì hợp lệ cho một beat.

### Table 11-1. Requirements on other owners

- **Để làm gì:** những gì IP khác phải làm thì debug mới chạy.
- **Cột:** Item, Owner, What it blocks (thiếu thì hỏng gì).
- **Dòng đáng chỉ:** tóm tắt ở bảng cuối mục 2. Nhấn mạnh ba dòng:
  - `i_rst_n_por` chỉ từ power-on (SCRC). HAS Table 4-2 đang OR watchdog chung với POR, vẫn open với HAS owner.
  - Xoá vùng `0xF000_0000` khỏi HAS Table 7-1, vì `SYSDBG` không có memory-mapped register.
  - `ISRAM` không reset để image sống qua watchdog.
- **Accepted limits:** không có timeout (slave không trả lời thì `busy` = 1 đến reset
  `S_BUS`); normal boot thì firmware có thể chiếm chân JTAG.

**Hỏi:** Không timeout có nguy hiểm không?
**Đáp:** `S_BUS` trả `DECERR` cho địa chỉ lạ, SCRC trả lời thay peripheral bị gate.
Nên mọi access đều có response. Trường hợp duy nhất mất response là bus reset, và đã có issue lại.

### Table A-1. Acronyms

Một dòng: bảng viết tắt (CDC, DR/IR, `dpc`, `dret`, POR, SCRC, TAP). Chỉ tra khi cần.

### Table B-1. First review

- **Để làm gì:** ý kiến review của thầy ngày 2026-09-23 và chỗ đã trả lời trong MAS.
- **Cột:** Item (ý kiến), Reviewer, Response (sửa ở đâu).
- **Dòng đáng chỉ:** "Ai nạp 4 KiB debug program" → 7.2, 7.8. "Debugger phải điều
  khiển CPU reset bằng pin ngoài" → `DBG_EN`, `CPUHOLD`, 7.1. "CPU clock" → không cần,
  vì cluster `cpu` không bao giờ bị gate.

**Hỏi:** Hình tham khảo của thầy được dùng thế nào?
**Đáp:** Làm pattern, chỉnh năm điểm cho QSOC: mã `CPUDBG`, mã lạ thành `BYPASS`, read
bắt đầu ở Update-DR `ADDR`, `AxiIdWidth` = 5, nội dung `STATUS` (`_DECISIONS` D18).
