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

**A. Debug boot (`DBG_EN` = 1): từ jumper trên board đến CPU chạy image đã nạp**

**Bước 1 — Đặt jumper, bật nguồn.** *Ở đâu:* board, người ngồi debug. *Làm gì:* đặt
jumper `DBG_EN` = 1, cắm JTAG adapter vào 5 pad JTAG, bật nguồn. *Đi tiếp:* pad `DBG_EN`
thành `i_dbg_en` vào `SYSDBG`; nguồn lên sinh `i_rst_n_por`. *Phụ thuộc:* `DBG_EN` nằm
trên một input pad, board có pull-down (Table 11-1), nên không có jumper là normal boot.
*(Vì sao: mode phải biết ngay từ t = 0, vì SCRC nhả CPU vài micro giây sau power-on, còn
host kết nối muộn hơn nhiều. Một register trong `SYSDBG` không làm được: reset về "hold"
thì chip không boot nếu không có probe, reset về "run" thì CPU đã chạy trước khi host
kịp ghi — D1.)*

**Bước 2 — Power-on reset toàn bộ SYSDBG.** *Ở đâu:* `SYSDBG`, cả ba domain. *Làm gì:*
`i_rst_n_por` reset TCK, AXI và system domain. `o_cpu_hold` là flip-flop reset 1; DR
`CPUHOLD` reset 1; `CPUDBG` reset 0. *Đi tiếp:* `o_cpu_hold` = 1 vào CPU reset
synchroniser của SCRC. *Phụ thuộc:* `i_rst_n_por` chỉ đến từ power-on, không từ watchdog.
*(Vì sao: reset 1 để CPU bị giữ từ t = 0 cho đến lúc `DBG_EN` được chốt (7.1). Phải là
flop vì `o_cpu_hold` là OR của ba term cùng đổi trong một cycle lúc capture; nếu là tổ
hợp nó có thể glitch xuống 0 và nhả reset CPU trong chốc lát — D20.)*

**Bước 3 — Chốt DBG_EN.** *Ở đâu:* system domain, khối `DBG_EN 2FF + capture`. *Làm gì:*
synchronise `i_dbg_en` và chốt **một lần**, `SyncStages` + 1 cycle `i_clk_cpu` sau khi
`i_rst_n_por` nhả. *Đi tiếp:* `o_dbg_en` = 1 ra boot_addr mux và IO MUX; từ đây
`o_cpu_hold` đi theo `CPUHOLD` (đang = 1). *Phụ thuộc:* không gì nữa; đổi pad sau lúc
này không có tác dụng cho đến power-on kế tiếp.
*(Vì sao: mode chỉ cần biết một lần rồi cố định đến power-on sau. Vì chỉ lấy mẫu sau
power-on, nếu hết pad thì `DBG_EN` có thể dùng chung một pad có IO MUX mặc định là input
— Table 11-1.)*

**Bước 4 — Chip chuyển sang chế độ debug boot.** *Ở đâu:* boot_addr mux và IO MUX. *Làm
gì:* mux chọn `0x2000_1000`; IO MUX ép 5 pad JTAG về chức năng JTAG. *Đi tiếp:*
`boot_addr_i` = `0x2000_1000` vào Ibex; `TCK`, `TMS`, `TDI`, `TRST_N` tới TAP của
`SYSDBG`, `TDO` ra host. *Phụ thuộc:* CPU owner làm mux `boot_addr_i = o_dbg_en ?
0x2000_1000 : 0x0000_0000`; IO MUX owner làm phần ép pad.
*(Vì sao: không có mux, CPU thả ra ở debug boot sẽ chạy ROM bootloader, ngồi chờ UART0
và không bao giờ tới image đã nạp — D4. Ép pad chỉ tốn một cổng logic, và firmware remap
chân không phá được debug boot nữa — D5.)*

**Bước 5 — SCRC nhả reset, nhưng CPU vẫn đứng.** *Ở đâu:* SCRC. *Làm gì:* nhả reset cho
bus, ROM, RAM, peripheral. *Đi tiếp:* reset CPU của SCRC được OR với `o_cpu_hold` (= 1)
trước CPU reset synchroniser, nên `rst_ni` của Ibex vẫn thấp. *Phụ thuộc:* SCRC phải OR
`o_cpu_hold` **trước** synchroniser; `fetch_enable_i` tied on, CPU chỉ bị giữ bằng reset.
*(Vì sao: OR đặt sau synchroniser có thể glitch khi SCRC nhả reset đúng cycle host set
hold — D2. Chỉ dùng một cơ chế giữ là reset: thêm `fetch_enable_i` thì cần một đường
release riêng, còn gate clock thì không cần vì cluster `cpu` hardwired on — Table 11-1,
D3.)*

**Bước 6 — Host bắt tay với TAP.** *Ở đâu:* host/JTAG adapter → TAP FSM của `SYSDBG`.
*Làm gì:* đưa TAP về Test-Logic-Reset; IR tự nạp `IDCODE`, host scan ra `0x0515_3001`.
*Đi tiếp:* từ đây mọi lệnh là một IR scan rồi một DR scan qua `TDI`/`TDO`. *Phụ thuộc:*
`TCK` asynchronous với `i_clk_cpu`, có thể nhanh, chậm hay dừng.
*(Vì sao: IEEE 1149.1 quy định Test-Logic-Reset nạp `IDCODE`.)*

**Bước 7 — Nạp debug window.** *Ở đâu:* host → DR `ADDR`, `DATA` trong TCK domain. *Làm
gì:* với mỗi word của `0x2000_0000`–`0x2000_0FFF`: IR = `ADDR`, DR = {1, A} (chưa phát
gì); IR = `DATA`, DR = D; Update-DR set `write_req`. *Đi tiếp:* `write_req` qua CDC →
AXI manager phát AW/W/B trên `AXI_S0` → `S_BUS` → `ISRAM`; `write_ack` về; host scan
`STATUS` đến khi `busy` = 0 và `resp` = `00` (handshake: Figure 7-2). *Phụ thuộc:* không
busy, vì lúc busy Update-DR bị bỏ qua; `AXI_S0` nối thẳng AXI4; nội dung window là host
software (`_DECISIONS`, "Debug window code").
*(Vì sao: đây là thiết kế reference của thầy: data register chính là interface, nên
không cần vùng register `0xF000_0000`, và AXI4 manager native bớt được adapter
`axi_from_mem` ở `AXI_S0` — D12, D13. Update-DR bị bỏ qua lúc busy để `addr_reg`,
`wdata_reg` đứng yên, nhờ vậy chúng cross không cần synchroniser — D14.)*

**Bước 8 — Nạp program image.** *Ở đâu:* host, cùng đường như bước 7. *Làm gì:* ghi image
từ `0x2000_1000`. *Đi tiếp:* `S_BUS` → `ISRAM`. *Phụ thuộc:* image link ở `0x2000_1000`,
reset entry `0x2000_1080` (Firmware owner).
*(Vì sao: để một image chạy được ở cả hai boot mode; ở normal boot bootloader cũng nhảy
tới `0x2000_1080` — Table 11-1.)*

**Bước 9 — (Tuỳ chọn) Đặt halt trước khi chạy.** *Ở đâu:* host → DR `CPUDBG`. *Làm gì:*
ghi `CPUDBG` = 1. *Đi tiếp:* `dbgreq` qua 2FF xuống system domain → `o_cpu_debug_req` = 1
→ `debug_req_i` của Ibex. *Phụ thuộc:* CPU đang bị giữ, nên core sẽ halt trước lệnh đầu.
*(Vì sao: dừng được ở lệnh đầu mà không cần hardware trigger (`DbgTriggerEn = 0`). Đây
cũng là cách debug ROM bootloader từ lệnh đầu: halt, ghi `dpc` = `0x0000_0080`, rồi step
— 7.2.)*

**Bước 10 — Thả CPU.** *Ở đâu:* host → DR `CPUHOLD`. *Làm gì:* ghi `CPUHOLD` = 0. *Đi
tiếp:* `cpu_hold` qua 2FF → `o_cpu_hold` = 0 → CPU reset synchroniser nhả `rst_ni` →
Ibex lấy lệnh đầu ở `0x2000_1080` trong `ISRAM`. Nếu có bước 9, core halt ngay, `dpc` =
`0x2000_1080`. *Phụ thuộc:* `o_dbg_en` = 1 (khi = 0, `CPUHOLD` vô tác dụng); SCRC đã nhả
reset CPU của chính nó.
*(Vì sao: `CPUHOLD` là data register theo kiểu của thầy, reset 1 bởi TRST và POR, nên
JTAG reset giữ lại CPU ở debug boot — D17. Nó bị chặn khi `DBG_EN` = 0 để normal boot
không bao giờ phụ thuộc probe, như bước 1.)*

**Bước 11 — Halt.** *Ở đâu:* host → `CPUDBG`, rồi Ibex. *Làm gì:* `CPUDBG` = 1; Ibex lưu
PC vào `dpc`, nhảy tới `DmHaltAddr` = `0x2000_0800`. *Đi tiếp:* code window lưu `s0`, `s1`
vào `dscratch0/1`, ghi `HALTED` = 1, vào dispatch loop; host đọc `HALTED` (read của 7.4)
để xác nhận. *Phụ thuộc:* CPU owner đặt `DmHaltAddr` = `0x2000_0800`, `DmExceptionAddr` =
`0x2000_0810`; window đã nạp ở bước 7.
*(Vì sao: không có debug ROM: code debug là host software, nên nằm trong window ở
`ISRAM` do host nạp — Table 9-1, `_DECISIONS` "Debug window code". Báo halt bằng flag
`HALTED` vì `ibex_top` không export `debug_mode`, sửa RTL vendored thì bị cấm, còn code
window vốn đã chạy mỗi lần halt — D19.)*

**Bước 12 — Đọc một thanh ghi, ví dụ `dpc`.** *Ở đâu:* host ↔ debug window, qua `SYSDBG`.
*Làm gì:* ghi `EXC` = 0; ghi sequence vào đầu window (`csrr s1, dpc` → ghi `DATA` → `CMD`
= 0 → `j LOOP`); ghi `CMD` = 1. *Đi tiếp:* loop thấy `CMD` ≠ 0 thì nhảy vào sequence; host
poll `CMD` đến 0, đọc `EXC` rồi `DATA`. *Phụ thuộc:* mỗi read là `ADDR` {0, A} → `STATUS`
→ `DATA`; chỉ một transaction outstanding nên các write tới đúng thứ tự. Flag `DATA`,
`EXC`, `CMD`, `RESUME`, `HALTED` ở offset `0x700`–`0x710` (`_DECISIONS`).
*(Vì sao: loop cần thanh ghi làm việc mà Ibex chỉ có hai scratch CSR, nên loop giữ `s0`,
`s1` và cất bản của chương trình vào `dscratch0/1` — D7. Sequence ghi `DATA` trước rồi
mới `CMD` = 0, để lúc host thấy `CMD` = 0 thì `DATA` đã đúng.)*

**Bước 13 — Resume.** *Ở đâu:* host, rồi loop trong window. *Làm gì:* ghi `CPUDBG` = 0
**trước**, rồi `RESUME` = 1. *Đi tiếp:* `o_cpu_debug_req` = 0 tới Ibex; loop xoá
`RESUME`, `HALTED`, khôi phục `s0`, `s1`, chạy `dret` → Ibex về `dpc`. *Phụ thuộc:* đúng
thứ tự: `debug_req` còn cao thì core halt lại ngay lệnh kế tiếp (7.7).
*(Vì sao: cho hardware tự xoá `CPUDBG` thì phải ghi ngược từ domain khác vào register
TCK, nên MAS giữ `CPUDBG` là mức do host đặt và nêu rõ thứ tự — D16.)*

**Kết thúc:** CPU ra khỏi Debug Mode và chạy tiếp image trong `ISRAM`; `HALTED` = 0.
Muốn chạy lại từ đầu: `CPUHOLD` = 1, sửa image, `CPUHOLD` = 0; `ISRAM` không bị xoá.

**B. Normal boot (`DBG_EN` = 0), attach sau**

**Bước B1 — Bật nguồn không jumper.** *Ở đâu:* board, system domain. *Làm gì:* pull-down
giữ `DBG_EN` = 0; chốt như bước 3. *Đi tiếp:* `o_dbg_en` = 0 → `boot_addr_i` =
`0x0000_0000`, pad JTAG theo IO MUX register (mặc định JTAG); `o_cpu_hold` = 0 vĩnh viễn.
*Phụ thuộc:* pull-down trên board.
*(Vì sao: như bước 1 và 10: không có probe thì chip vẫn boot bình thường.)*

**Bước B2 — CPU chạy bootloader.** *Ở đâu:* SCRC, Ibex. *Làm gì:* SCRC nhả CPU; Ibex chạy
ROM từ `0x0000_0080`. *Đi tiếp:* bootloader nhảy tới image ở `0x2000_1080`. *Phụ thuộc:*
Firmware owner: cùng một image cho cả hai mode.
*(Vì sao: như bước 8.)*

**Bước B3 — Attach.** *Ở đâu:* host → `SYSDBG` → `ISRAM`. *Làm gì:* ghi debug window như
bước 7, trong lúc CPU đang chạy. *Đi tiếp:* halt, đọc, resume như bước 11–13. *Phụ thuộc:*
window xong trước lần halt đầu; firmware chưa remap pad JTAG (nếu có, dùng debug boot).
*(Vì sao: AXI manager đọc/ghi được cả khi CPU chạy, nên attach không cần dừng CPU
(section 2 của MAS). Pad chỉ bị ép ở debug boot (bước 4), nên ở normal boot firmware có
thể chiếm chân JTAG; MAS chấp nhận giới hạn này.)*

**Kết thúc:** CPU chạy tiếp firmware sau `dret`.

**C. Watchdog bite hoặc software reset**

**Bước C1 — SCRC reset bus và CPU.** *Ở đâu:* SCRC. *Làm gì:* reset domain `S_BUS` và CPU.
*Đi tiếp:* `i_rst_n_sysbus` vào `SYSDBG`. *Phụ thuộc:* `i_rst_n_por` không nhận watchdog.
*(Vì sao: để `DBG_EN` đã chốt và hold sống qua watchdog — Table 11-1. HAS Table 4-2 đang
đưa watchdog vào chung cổng OR với power-on, nên điểm này còn open với HAS owner.)*

**Bước C2 — SYSDBG chỉ mất AXI domain.** *Ở đâu:* `SYSDBG`. *Làm gì:* AXI domain reset; TCK
và system domain giữ `o_dbg_en`, `dbgreq`, `cpu_hold`, các DR. *Đi tiếp:* transaction dở
thì `req` vẫn giữ bên TCK; khi `i_rst_n_sysbus` nhả, AXI manager thấy cạnh lên và
**issue lại**; host chỉ thấy `busy` lâu hơn. *Phụ thuộc:* làm lại một word read/write là vô hại.
*(Vì sao: không cần timeout vì mọi access đều có response: `S_BUS` trả `DECERR` cho địa
chỉ lạ, SCRC trả lời thay peripheral bị gate. Trường hợp duy nhất mất response là bus
reset, và issue lại che được nó — D15.)*

**Bước C3 — CPU khởi động lại.** *Ở đâu:* SCRC, Ibex, `ISRAM`. *Làm gì:* CPU theo SCRC rồi
theo 7.1. *Đi tiếp:* debug boot với `CPUHOLD` = 0 → chạy lại từ `0x2000_1080`;
`CPUHOLD` = 1 → vẫn bị giữ; normal boot → bootloader. *Phụ thuộc:* `ISRAM` không reset,
không clear-on-reset, nên window và image còn nguyên.
*(Vì sao: để image sống qua watchdog hay software reset — Table 11-1. Lúc đang nạp ở
debug boot thì CPU bị hold và watchdog tắt, nên chỉ mất nguồn mới cắt ngang được việc
nạp.)*

**Kết thúc:** chip chạy lại; ở debug boot, host không phải nạp lại window hay image.

Riêng `i_jtag_trst_n`: chỉ reset TCK domain, `dbgreq` = 0, `cpu_hold` = 1. Ở debug
boot, CPU bị giữ lại.
*(Vì sao: như bước 10 (D17).)*

| IP liên quan | SYSDBG cần gì từ IP đó |
|---|---|
| Host / JTAG adapter | Chạy đúng sequence 7.4, nạp debug window, giữ thứ tự `CPUDBG` = 0 rồi `RESUME` = 1 |
| Top / pad owner | `DBG_EN` trên một input pad, pull-down trên board |
| SCRC | `i_rst_n_por` chỉ từ power-on; OR `o_cpu_hold` vào CPU reset **trước** synchroniser |
| S_BUS | `AXI_S0` nối thẳng, AXI4, ID width 5; luôn trả response (`DECERR` cho địa chỉ lạ) |
| ISRAM (RAM owner) | Array không reset, không clear-on-reset |
| Ibex (CPU owner) | Boot address mux theo `o_dbg_en`; `DmHaltAddr` = `0x2000_0800`, `DmExceptionAddr` = `0x2000_0810`; `fetch_enable_i` tied on |
| IO MUX | Ép 5 pad JTAG về JTAG khi `o_dbg_en` = 1 |
| Firmware | Link image ở `0x2000_1000`, entry `0x2000_1080`; không đặt gì vào window |

## 3. Giải thích từng hình

### Figure 3-1. SYSDBG block diagram

Hình này trả lời: bên trong `SYSDBG` có gì, FSM ở đâu, CDC ở đâu, ba domain tách nhau
thế nào.

Em đi từ trái sang phải. Ngoài cùng bên trái là ô **JTAG pads**, trong ô ghi `TCK TMS TDI
TDO TRST_N`: đây là 5 chân host cắm vào. Mũi tên `TMS` đi vào khung nét đứt đầu tiên,
**TCK domain · i_jtag_tck · TRST_N & POR**: domain này chạy trên `TCK`, reset bằng TRST
hoặc POR. `TMS` vào ô **TAP FSM**, trong ô ghi "16 states". Đây là state machine chuẩn
IEEE 1149.1. Từ TAP FSM có mũi tên sang ô **control signals**, ghi "capture shift update":
FSM giải mã state thành ba lệnh đó. Từ ô này mũi tên đi xuống khối data register.

Mũi tên thứ hai từ JTAG pads ghi `TDI`, đi vào ô **IR 4 bit**, thanh ghi lệnh 4 bit. Hình
vẽ `TDI` vào IR; khi đang Shift-DR thì `TDI` shift vào DR được chọn. Từ IR có mũi tên
`select` đi xuống ô lớn ghi **ADDR 33 · DATA 32 · STATUS 3 / CPUDBG 1 · CPUHOLD 1 /
IDCODE 32 · BYPASS 1**: bảy data register, con số là độ dài (Table 6-1).

Từ khối data register có ba hướng ra. Một, mũi tên xuống ô **TDO mux**, ghi "falling-edge
flop": chọn bit ra, đổi ở cạnh xuống `TCK`. Từ đó mũi tên `TDO` quay về JTAG pads. Hai,
mũi tên `Update-DR` xuống ô in đậm **read_req · write_req / busy**: Update-DR của `ADDR`
hoặc `DATA` set request, và `busy` = handshake chưa về idle. Ba, mũi tên ngang sang phải
vào ô CDC, mang `addr`, `wdata`; một mũi tên từ CDC quay về khối này, mang `rdata`, `resp`.

Ô read_req · write_req cũng có mũi tên sang ô in đậm **CDC**. Trong ô CDC ghi đủ mọi tín
hiệu cross: `read_req ->`, `<- read_ack`, `write_req ->`, `<- write_ack`, `dbgreq ->`,
`cpu_hold ->`, "2FF each"; rồi `addr wdata ->`, `<- rdata resp`, "set_max_delay". Tức là
control đi qua 2FF, còn data bus đi thẳng dưới `set_max_delay` (Table 7-4).

Từ CDC có mũi tên lên khung **AXI domain · i_clk_cpu · i_rst_n_sysbus**, vào ô **2FF +
edge**, ghi "set_ar · set_aw": synchroniser và bắt cạnh lên của request. Mũi tên tiếp sang
ô in đậm **AXI manager**, ghi "AR R · AW W B": năm channel AXI. Mũi tên `AXI4` đi ra ngoài
vào ô **S_BUS AXI_S0**. Từ AXI manager có mũi tên `R B` đi xuống ô **rdata_reg · resp_reg
/ read_ack · write_ack**: chốt data, response và phát ack. Ô này có mũi tên quay về CDC.

Mũi tên thứ ba từ CDC đi xuống khung **system domain · i_clk_cpu · i_rst_n_por**, vào ô
**dbgreq · cpu_hold / 2FF**. Bên dưới là ô **DBG_EN / 2FF + capture**, nhận mũi tên
`i_dbg_en` từ ô **DBG_EN pad** ở góc dưới bên trái: pad đi thẳng vào system domain, không
qua TCK. Hai ô này cùng có mũi tên vào ô **o_cpu_debug_req / o_dbg_en · o_cpu_hold**: các
flop output. Từ đó mũi tên `debug_req` đi lên ô **Ibex CPU**, và một mũi tên đi sang ô
**SCRC · boot mux / IO MUX**, mang `o_cpu_hold` và `o_dbg_en` (chi tiết ở Figure 7-1).

**Tóm lại:** bên trái là JTAG thuần, chạy trên `TCK`. Bên phải là hai domain cùng
`i_clk_cpu` nhưng khác reset. Mọi thứ đổi domain đều đi qua đúng một ô CDC ở giữa.

**Hỏi:** FSM ở đâu, CDC ở đâu?
**Đáp:** FSM là TAP FSM trong TCK domain. AXI manager là các flop valid/ready
set/clear theo Table 7-3. CDC là ô giữa; tín hiệu nào cross đều ghi trong đó và trong Table 7-4.

**Hỏi:** AXI domain và system domain cùng `i_clk_cpu`, sao tách làm hai?
**Đáp:** Khác reset. AXI domain reset theo `S_BUS`; system domain chỉ theo power-on,
nên `o_dbg_en` và hold sống qua watchdog (mục 2, phần C).

**Hỏi:** Sao TCK domain reset bằng cả TRST và POR?
**Đáp:** Để `CPUHOLD` = 1 ngay từ power-on, kể cả khi adapter chưa cắm hay không lái TRST.

**Hỏi:** Sao TDO ra ở cạnh xuống?
**Đáp:** IEEE 1149.1 quy định vậy: TDO đổi ở cạnh xuống để host lấy mẫu ở cạnh lên.

### Figure 7-1. Debug boot wiring

Hình này trả lời: `SYSDBG` nối với phần còn lại của chip thế nào để làm debug boot.

Em bắt đầu ở góc trên bên trái. Ô **DBG_EN pad** có mũi tên `i_dbg_en` vào ô lớn in đậm
**SYSDBG**. Ngay dưới là ô **JTAG pads**, mũi tên `JTAG` cũng vào SYSDBG: đó là 5 chân host.

Từ SYSDBG có bốn nhóm dây ra. Mũi tên `o_dbg_en` thứ nhất vào ô **IO MUX**, ghi "JTAG
pads = JTAG": khi `o_dbg_en` = 1, IO MUX ép 5 pad về JTAG. Mũi tên `o_dbg_en` thứ hai vào
ô **boot_addr mux**, ghi "0: 0x0000_0000 / 1: 0x2000_1000": chọn ROM hay `ISRAM`. Từ mux,
mũi tên `boot_addr_i` vào ô **Ibex CPU**.

Mũi tên `o_cpu_hold` vào ô ghi "SCRC: CPU reset / synchroniser / hold OR cpu reset". Ô
này nằm **trong SCRC**. Ô **SCRC sequencer** ở dưới (phần SCRC nhả reset theo thứ tự) có
mũi tên đi lên vào cùng ô, mang reset CPU của SCRC. Tức là OR xảy ra **trước**
synchroniser. Từ đây mũi tên `rst_ni` vào Ibex CPU.

Dây trên cùng, ghi `debug_req`, đi từ đỉnh SYSDBG sang Ibex CPU: đây là đường halt. Cuối
cùng, dây `AXI4` đi từ đáy SYSDBG vào ô **S_BUS / AXI_S0**. Ibex CPU cũng có mũi tên xuống
S_BUS, vì Ibex là manager khác trên cùng bus. Từ S_BUS mũi tên xuống ô **ISRAM**, nơi chứa
debug window và image.

**Tóm lại:** một bit `o_dbg_en` quyết định ba thứ: pad JTAG, boot address, và `CPUHOLD`
có tác dụng hay không. `o_cpu_hold` giữ reset Ibex trong lúc host nạp `ISRAM` qua AXI4,
và `debug_req` dùng để halt khi CPU đã chạy.

**Hỏi:** Sao OR `o_cpu_hold` **trước** synchroniser mà không OR sau?
**Đáp:** OR sau synchroniser có thể glitch khi SCRC nhả reset đúng cycle host set hold.
Qua synchroniser thì release luôn sạch và đồng bộ.

**Hỏi:** Không có boot_addr mux thì sao?
**Đáp:** CPU sẽ chạy ROM bootloader, ngồi chờ UART0, không bao giờ tới image đã nạp.

**Hỏi:** Sao không giữ CPU bằng `fetch_enable_i`?
**Đáp:** Đã có một cơ chế giữ là reset. Thêm hold thứ hai thì lại cần một đường release riêng.

**Hỏi:** Sao IO MUX phải ép pad JTAG?
**Đáp:** Để firmware remap pad không làm hỏng debug boot. Một cổng logic là đủ.

### Figure 7-2. Read handshake

Hình này trả lời: một lệnh read đi qua CDC thế nào, flop nào set, flop nào clear.

Hình có hai khung nét đứt: **TCK domain** bên trái, **AXI domain** bên phải. Em bắt đầu ở
góc trên bên trái, trong TCK domain. Ô **Update-DR ADDR**, ghi "addr[32] = 0, not busy",
là điều kiện bắt đầu read. Mũi tên `set` đi vào ô in đậm **read_req_reg**: flop request.

Từ read_req_reg, mũi tên `read_req` cắt qua ranh giới, vào AXI domain, ô **2FF · dly**:
hai flop synchroniser và một flop delay. Mũi tên tiếp vào ô **set_ar**, ghi "sync & !dly":
đầu ra 2FF bằng 1 mà flop delay còn 0, tức là cạnh lên của request. Mũi tên tiếp vào ô in
đậm **AR · R**: AXI manager phát `arvalid`, `rready`.

Ở dưới cùng có ô **addr_reg[31:0]** trong TCK domain. Mũi tên ghi "set_max_delay 1 AXI
clock" đi thẳng sang ô **araddr** ở AXI domain, không qua synchroniser.

Từ AR · R, mũi tên `rvalid` đi xuống ô **rdata_reg / resp_reg**: khi R handshake xong thì
chốt `rdata` và `rresp`, và hạ `rready`. Mũi tên sang trái vào ô in đậm **read_ack_reg**,
ghi "dly & !rready": `ack` lên khi request còn giữ mà `rready` đã về 0. Từ ô này mũi tên
`read_ack` về TCK domain, vào ô **2FF · dly** bên TCK.

Từ 2FF · dly bên TCK có hai đường. Chữ `rising edge` chỉ sang ô **Data register /
Response register**: cạnh lên của `ack` chốt data và response. Đường data này đến từ
rdata_reg, theo mũi tên dài ghi "rdata · resp set_max_delay 1 TCK". Mũi tên thứ hai ghi
`clear` đi lên read_req_reg: request bị xoá. Sau đó `ack` xuống theo, và `busy` hết.

Khung nét đứt dưới cùng ghi "write: Update-DR DATA, addr[32] = 1 · AW W B · write_req /
write_ack": write đi y hệt, chỉ khác điểm bắt đầu và channel AXI.

**Tóm lại:** chỉ `req` và `ack` qua synchroniser. `addr`, `rdata`, `resp` đi thẳng vì
chúng đứng yên suốt lúc handshake chưa về idle. Sáu pha của hình đúng như 7.6.

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

## 5. Vì sao con số này

Nguồn: MAS, `_DECISIONS` (bảng D1–D20, "Debug window code"), chuẩn IEEE 1149.1 / AXI4,
và hình tham khảo `VLSI_SYSDBG.drawio` của thầy (ghi "theo hình của thầy").

| Con số | Ở đâu (bảng/hình) | Vì sao | Nếu khác thì sao |
|---|---|---|---|
| TAP FSM "16 states" | Figure 3-1 | IEEE 1149.1 định nghĩa TAP controller đúng 16 state. | Không còn là TAP chuẩn; adapter không lái được. |
| IR 4 bit | Figure 3-1, Table 6-1 | Theo hình của thầy (IR 4 bit, D12). Bảy lệnh cần tối thiểu 3 bit. | 3 bit (8 mã) chứa đủ 7 lệnh nhưng chỉ dư 1 mã; IR dài hơn thì mỗi IR scan tốn thêm `TCK`. |
| `ADDR` 33 bit | Figure 3-1, Table 6-1 | 32 bit địa chỉ + bit 32 chọn chiều (0 read, 1 write). Theo hình của thầy. | Thiếu bit chiều thì Update-DR của `DATA` không biết có phải bắt đầu write hay không. |
| `DATA` 32 bit | Figure 3-1, Table 6-1 | Một word, bằng độ rộng `rdata`/`wdata` của AXI. Theo hình của thầy. | Hẹp hơn thì một word cần nhiều scan; rộng hơn thì thành burst, mà block chỉ làm word. |
| `STATUS` 3 bit | Figure 3-1, Table 6-1 | `busy` + `resp[1:0]` của AXI. Hình của thầy chỉ cho độ rộng, nội dung do MAS chọn (D18). | Không có `busy` thì host không biết lúc nào đọc `DATA`; không có `resp` thì không thấy SLVERR/DECERR. |
| `CPUDBG` 1, `CPUHOLD` 1 bit | Figure 3-1, Table 6-1 | Mỗi cái là một mức: halt / không halt, giữ / thả. | Không cần thêm bit. |
| `IDCODE` 32, `BYPASS` 1 bit | Figure 3-1, Table 6-1 | IEEE 1149.1 quy định độ dài cả hai. | Host đếm device trên chain sai. |
| Bảy data register | Section 2, Figure 3-1 | 3 cho bus (`ADDR`, `DATA`, `STATUS`), 2 cho CPU (`CPUDBG`, `CPUHOLD`), 2 theo chuẩn (`IDCODE`, `BYPASS`). | -- |
| `0100`, `0101`, `0110`, `1110`, `1111` | Table 6-1 | `ADDR`, `DATA`, `STATUS`, `IDCODE`, `BYPASS` giữ đúng mã của hình thầy. `BYPASS` toàn 1 là quy định IEEE 1149.1. | `BYPASS` khác `1111` là trái chuẩn; các mã khác đổi được nếu host software đổi theo. |
| `CPUDBG` `0111`, `CPUHOLD` `1000` | Table 6-1 | Hai mã trống kế tiếp sau `0110`. Hình thầy dùng `1110` cho `CPUDBG`, trùng `IDCODE` (D18). | Dùng `1110` thì một mã chọn hai register. |
| Mã còn lại hoạt động như `BYPASS` | Table 6-1 | IEEE 1149.1: mã không dùng phải chọn một DR hợp lệ (D18). | Để X thì scan vào mã lạ cho kết quả không xác định. |
| Capture-IR `0001` | Section 6, Table 6-1 | IEEE 1149.1 bắt buộc 2 bit thấp là `01`; 2 bit cao để 0 theo quy ước. | Host dùng mẫu `01` để kiểm tra chain; sai thì báo lỗi chain. |
| Reset: `CPUHOLD` = 1, còn lại 0 | Table 6-1 | Xem bước 2 và 10 ở mục 2 (D17). | `CPUHOLD` reset 0 thì CPU chạy trước khi host kịp nạp. |
| `resp` `00` / `10` / `11` | Table 6-1 note | Mã response của AXI: OKAY, SLVERR, DECERR. EXOKAY (`01`) không xảy ra vì không có exclusive access (`lock` = 0). | -- |
| `rresp`, `bresp` 2 bit | Table 5-1 | Độ rộng response của AXI4. | -- |
| `araddr`/`awaddr` 32 bit, `[1:0]` = 0 | Table 5-1, Table 6-1 | Không gian địa chỉ 32 bit của QSOC; chỉ truy cập word nên 2 bit thấp bỏ qua. | Địa chỉ lệch word sẽ trái với `size` = 4 byte. |
| `IdcodeValue` = `0x0515_3001` | Table 5-2 | Version `0x0` (bit 31:28), part `0x5153` = hex-ASCII "QS" (bit 27:12), manufacturer `0x000` vì QSOC không có JEDEC ID (bit 11:1), bit 0 = 1 theo IEEE 1149.1. | Bit 0 = 0 thì host hiểu là không có `IDCODE`; mượn ID dự án khác thì báo sai cho host. |
| `AxiIdWidth` = 5 | Table 5-2 | Độ rộng ID cổng slave của `S_BUS` trong HAS (D18); hình thầy ghi 4 vì là SoC khác. | Lệch độ rộng port ở `AXI_S0`. |
| `SyncStages` = 2, "2FF" | Table 5-2, Figure 3-1, 7-2 | Synchroniser hai flop là mức chuẩn chống metastability; chỉ tăng lên 3 nếu phân tích timing yêu cầu (`_DECISIONS`). | 1 flop: rủi ro metastability; 3 flop: thêm một cycle trễ mỗi lần cross. |
| Capture `DBG_EN` ở `SyncStages` + 1 cycle | Section 7.1 | `SyncStages` cycle qua synchroniser, thêm 1 cycle cho flop chốt. | -- |
| Một flop delay sau 2FF | Table 7-4, Figure 7-2 ("dly") | Bắt cạnh cần giá trị cũ: `set_ar` = `sync & !dly`. | Không có thì một request phát nhiều transaction. |
| `set_max_delay` một chu kỳ clock đích | Table 7-4, Figure 7-2 ("1 TCK", "1 AXI clock") | Data bus đứng yên suốt handshake; bên nhận chỉ đọc nó sau khi `req`/`ack` qua ≥ 2 flop, nên data chỉ cần tới trong một chu kỳ. `-datapath_only` vì hai clock không liên quan. | Không constraint thì tool không kiểm path, data có thể tới muộn hơn tín hiệu control. |
| `i_clk_cpu` 20 MHz | Table 5-1 | Tần số chung của cả chip, do HAS/contract quy định; không PLL vì PDK SMIC 28 nm không có analog IP. | `SYSDBG` không phụ thuộc giá trị này; `TCK` asynchronous. |
| 5 pad JTAG (`TCK`, `TMS`, `TDI`, `TDO`, `TRST_N`) | Table 7-1, Figure 7-1 | IEEE 1149.1: 4 chân bắt buộc, `TRST_N` tuỳ chọn; QSOC có `TRST_N` để reset TCK domain, `cpu_hold` về 1. | Bỏ `TRST_N` thì DR của TCK domain chỉ reset được bằng POR. |
| `boot_addr_i` `0x0000_0000` / `0x2000_1000` | Table 7-1, Figure 7-1 | Base của ROM và base của `ISRAM` sau 4 KiB window. | Xem bước 4 ở mục 2 (D4). |
| Lệnh đầu `+0x80` (`0x0000_0080`, `0x2000_1080`) | Table 7-1 | Ibex nhảy tới `boot_addr_i` + `0x80` khi ra reset; 128 byte đầu là vector table. | -- (do Ibex quy định). |
| Image ở `0x2000_1000` | Table 7-1, 11-1 | Hệ quả của 4 KiB window đầu `ISRAM`. | Image đè lên window. |
| Window 4 KiB, `0x2000_0000`–`0x0FFF` | Table 7-5, B-1 | 4 KiB đầu `ISRAM` (RAM MAS); bằng `DmAddrMask` mặc định `0xFFF` của Ibex. Đặt ở **đầu** `ISRAM` để các parameter của Ibex chỉ phụ thuộc base. | Đặt ở cuối thì mỗi lần đổi dung lượng `ISRAM` phải rebuild CPU. |
| `0x000`–`0x7FF` sequence và flag | Table 7-5 | Code window dùng `sw`/`lw` với offset từ `s0` = `0x2000_0000`; immediate 12 bit có dấu chỉ tới `0x7FF` (D7). | Flag ở `0xF00` thì lệnh `sw` không assemble được. |
| Mailbox `0x700`–`0x710` (`DATA`, `EXC`, `CMD`, `RESUME`, `HALTED`) | `_DECISIONS` "Debug window code" | Phải dưới `0x800` (như dòng trên); vị trí cụ thể chọn theo quy ước, để `0x000`–`0x6FF` cho sequence. | -- |
| `DmHaltAddr` = `0x2000_0800` | Table 7-5, 11-1 | Base + `HaltAddress` (`0x800`) của `dm_pkg`, quy ước của `riscv-dbg`. | Không có code hợp lệ ở đây thì halt nhảy vào rác. |
| `DmExceptionAddr` = `0x2000_0810` (+16 byte) | Table 7-5, 11-1 | `dm_pkg::ExceptionAddress` = `HaltAddress` + 16. `ENTRY` là đúng 4 lệnh (16 byte), vừa trước `TRAP`. | Để mặc định Ibex `+8` thì exception trong Debug Mode rơi vào đường resume của `riscv-dbg`. |
| Loop từ `0x2000_0820` | Table 7-5 | `TRAP` cũng là 4 lệnh, nên `PARK` bắt đầu ở `0x810` + 16. | -- |
| `DbgTriggerEn` = 0 | Table 9-1 | Không cần hardware trigger: halt trước lệnh đầu rồi ghi `dpc` (7.2). | -- |
| `arlen`/`awlen` = 0, `wlast` = 1 | Table 10-1 | AXI `len` = số beat − 1, nên 0 là một beat; beat duy nhất cũng là beat cuối. | -- |
| `arsize`/`awsize` = `3'b010`, `wstrb` = `4'b1111` | Table 10-1 | `size` = 2^2 = 4 byte; ghi đủ 4 byte. Chỉ word. | Byte/halfword làm bằng read-modify-write ở host. |
| `arburst`/`awburst` = `2'b01` (INCR) | Table 10-1 | Hợp lệ cho một beat. | Với một beat, burst type không ảnh hưởng. |
| `arid`/`awid` = 0 | Table 10-1 | Chỉ một transaction outstanding, không cần phân biệt ID. | -- |
| `lock`, `prot`, `cache`, `qos`, `region` = 0 | Table 10-1 | Không exclusive access, không protection, không cache hint, không QoS. | -- |
| Vùng `0xF000_0000` | Table 11-1 | `SYSDBG` không có memory-mapped register, nên vùng này trong HAS Table 7-1 thừa. | -- |
| Ba domain | Section 3, Figure 3-1 | Ba tổ hợp clock/reset khác nhau: `TCK` + TRST & POR, `i_clk_cpu` + `i_rst_n_sysbus`, `i_clk_cpu` + `i_rst_n_por`. | Xem Figure 3-1, câu hỏi thứ hai. |
| V3.0 | Revision history | Số version của tài liệu, không phải thông số thiết kế. | -- |
