# Thuyết trình RAM (ISRAM / DSRAM) — bản đọc

**Khớp tài liệu:** `QNSC_RAM_MAS` V2.2 · **Ngày:** 2026-09-24

## 1. RAM là gì

`ISRAM` và `DSRAM` là hai RAM on-chip của QSOC. Mỗi cái là một instance của
`m_qnsc_wrap_axi4_sram`: IP `AXI4-SRAM-CONTROLLER` giữ nguyên, cộng thêm một write-strobe
FIFO, đặt trước một SMIC 28 nm single-port SRAM macro. `ISRAM` 64 KiB trên `AXI_M1` chứa
chương trình; `DSRAM` 32 KiB trên `AXI_M2` chứa stack, heap và biến. Khối không decode
địa chỉ, không bao giờ trả error response, và không có register.

## 2. Flow end-to-end

**A. CPU store (ví dụ `sb`, ghi 1 byte vào `DSRAM`)**

1. **Ibex** chạy lệnh store, phát địa chỉ, data và 4-bit byte enable.
2. **CPU2AXI** đổi request đó thành AXI4 write: một beat AW, một beat W. Byte enable
   thành `wstrb`. Đây là yêu cầu em đặt cho bus owner (Table 11-1).
3. **S_BUS** decode địa chỉ: `0x3000_xxxx` đi ra `AXI_M2`, `0x2000_xxxx` ra `AXI_M1`.
   Địa chỉ không thuộc vùng nào thì S_BUS trả `DECERR`, không tới RAM.
4. **AW vào RAM.** `awready` = address FSM idle và `AWFIFO` chưa full. Sau handshake,
   `u_axfsm_wr` đẩy vào `AWFIFO` một entry mỗi beat: address, ID, last flag.
5. **W vào RAM.** `wready` = `WFIFO` chưa full. Cùng một cycle `wvalid & wready`:
   `wdata` vào `WFIFO`, `wstrb` vào `u_strbfifo`.
6. **Xin quyền.** Khi `AWFIFO` và `WFIFO` đều có data, `u_sram_misc` bật `req_write`.
   `u_arbiter` round-robin cấp quyền; nếu chỉ có một request thì cấp ngay cycle đó.
7. **Ghi macro.** Trong cycle được cấp quyền: pop `AWFIFO` và `WFIFO`, `o_sram_we` = 1,
   `o_sram_addr` = byte address `[14:2]`, `o_sram_wdata` = data. Cũng chính `o_sram_we`
   pop `u_strbfifo`, và `o_sram_bwe` = strobe ở head. Macro chỉ ghi byte có bit
   byte enable = 1; ba byte bên cạnh giữ nguyên.
8. **B response.** Nếu beat đó là last, `BFIFO` nhận {ID, `BRESP` = `00`}. `bvalid` =
   `BFIFO` không rỗng, 3 cycle sau AW handshake (Table 7-2). B đi ngược qua S_BUS,
   CPU2AXI về Ibex.

**B. CPU load (hoặc instruction fetch từ `ISRAM`)**

1. Ibex → CPU2AXI → S_BUS → `AXI_M1`/`AXI_M2`, như bước A1–A3 nhưng trên kênh AR.
2. `arready` = FSM idle và `ARFIFO` chưa full. `u_axfsm_rd` đẩy mỗi beat một entry
   vào `ARFIFO`.
3. **Read issue** khi: `ARFIFO` có data, `RFIFO` chưa full, không có read nào đang
   pending, và arbiter cấp quyền. Cycle đó `o_sram_oe` = 1 và địa chỉ ra macro.
4. Cycle kế tiếp, `i_sram_rdata` được lấy mẫu và đẩy vào `RFIFO` cùng ID,
   `RRESP` = `00` và last flag.
5. `rvalid` = `RFIFO` không rỗng, 4 cycle sau AR handshake. R đi ngược qua S_BUS,
   CPU2AXI về Ibex.

**C. Nạp `ISRAM` lúc boot.** Macro không có reset, nên RAM không tự có chương trình.

1. **Normal boot** (`DBG_EN` = 0): Ibex chạy ROM bootloader, nhận ảnh qua **UART0**, rồi
   ghi ảnh vào `ISRAM` từ `0x2000_1000` (mỗi lần ghi là flow A). Xong thì nhảy
   vào `0x2000_1080`.
2. **Debug boot** (`DBG_EN` = 1): CPU bị giữ reset. Host đi JTAG → **SYSDBG** (AXI4
   manager trên `AXI_S0`) → S_BUS → `AXI_M1`. Host ghi debug window
   `0x2000_0000`–`0x2000_0FFF` và ảnh từ `0x2000_1000`, rồi thả CPU.
3. RAM không phân biệt hai đường này: với nó đều là AXI4 write bình thường.

**D. Watchdog hoặc software reset**

1. `i_rst_n_mem` assert (nguồn: power-on, watchdog, software).
2. Mọi flop trong controller và `u_strbfifo` về 0: FSM về `S_IDLE`, FIFO rỗng, arbiter
   toggle và read-pending = 0.
3. Transaction đang dở bị bỏ, không có response.
4. Sau reset: `awready`, `arready`, `wready` = 1; `bvalid`, `rvalid` = 0.
5. **Macro array giữ nguyên** vì không có reset và không có clear-on-reset. Chương trình
   trong `ISRAM` chỉ mất khi mất nguồn.

| IP liên quan | RAM cần gì từ IP đó |
|---|---|
| Ibex | Phát byte enable cho `sb`, `sh` |
| CPU2AXI | Mang byte enable ra `wstrb` |
| S_BUS | Decode window đúng bằng cỡ macro, `DECERR` cho địa chỉ lạ, ID width 7 |
| DMA | Không phát `WRAP` hay narrow burst vào RAM (câu hỏi còn mở) |
| ROM bootloader + UART0 | Nạp `ISRAM` ở normal boot |
| SYSDBG | Nạp debug window và ảnh ở debug boot |
| Firmware | Để trống 4 KiB đầu `ISRAM`, link ảnh ở `0x2000_1000` |
| Cluster `mem` | `i_clk_mem` 20 MHz không bao giờ gate; `i_rst_n_mem` |
| Physical design | Tie chân margin, retention, test của macro (Table 10-1) |

## 3. Giải thích từng hình

### Figure 3-1. The RAM block: wrapper, unmodified controller and macro. Heavy outline: the strobe FIFO QSOC adds

Hình này trả lời: bên trong khối RAM có gì, và phần nào là của em thêm vào.

| Block | Là gì | Nối với ai / tín hiệu |
|---|---|---|
| `i_clk_mem`, `i_rst_n_mem` | Clock và reset từ cluster `mem` | Vào toàn bộ wrapper |
| S_BUS `AXI_M1` / `AXI_M2` | Cổng master của bus, nhìn từ phía RAM | Năm kênh W, AW, AR, R, B |
| `m_qnsc_wrap_axi4_sram` | Wrapper, file của QSOC | Chứa `u_ctrl` và `u_strbfifo` |
| `u_strbfifo` (viền đậm) | FIFO 4 bit × 8 chứa `wstrb` | Vào: `wstrb` từ W. Pop: `o_sram_we`. Ra: `bwe[3:0]` |
| `u_ctrl` = `m_vlsi_axi4_sram` | IP controller, không sửa | Mọi box bên trong khung chấm nhỏ |
| `u_axfsm_wr`, `u_axfsm_rd` | Address FSM: handshake, sinh địa chỉ từng beat | AW → `AWFIFO`; AR → `ARFIFO` |
| `WFIFO` | Chứa write data | `wdata` → `u_sram_misc` |
| `AWFIFO`, `ARFIFO` | Chứa address, ID, last của từng beat | → `u_sram_misc` |
| `RFIFO` | Chứa read data, ID, `RRESP`, last | `u_sram_misc` → kênh R |
| `BFIFO` | Chứa ID, `BRESP` | `u_sram_misc` → kênh B |
| `u_sram_misc` | Pop FIFO, mux ra SRAM, sinh R và B | `req_write`, `req_read` ↔ `arb_sel`, `write_en` |
| `u_arbiter` | Round-robin giữa write và read | Nhận request, trả grant cho `u_sram_misc` |
| SRAM macro | Single port, đọc 1 cycle, không reset | `addr`, `wdata`, `we`, `oe`, `bwe` vào; `rdata` ra |

Cách đọc mũi tên:

1. Trái sang phải là request: AW, AR qua FSM rồi vào FIFO; W vào thẳng `WFIFO`.
2. Nhánh W tách đôi: `wdata` vào `WFIFO`, `wstrb` rẽ lên `u_strbfifo`.
3. `u_sram_misc` gửi request xuống `u_arbiter`, nhận grant lên, rồi lái macro.
4. Khi ghi, `o_sram_we` vừa ra macro vừa quay lên pop `u_strbfifo`, nên `bwe` ra đúng lúc.
5. `rdata` đi phải sang trái: macro → `u_sram_misc` → `RFIFO` → kênh R.
6. B không cần data từ macro: `u_sram_misc` đẩy vào `BFIFO` khi ghi beat last.
7. `addr[15:2] / [14:2]`: `ISRAM` dùng `[15:2]`, `DSRAM` dùng `[14:2]` (Table 8-1).

**Hỏi:** Sao `u_strbfifo` nằm ngoài controller?
**Đáp:** IP không có input `WSTRB`, và em giữ IP nguyên vẹn. Nên wrapper thêm một FIFO
riêng chạy song song với `WFIFO`.

**Hỏi:** Làm sao chắc strobe khớp đúng beat data?
**Đáp:** Hai FIFO push cùng điều kiện, pop cùng điều kiện, cùng depth, nên luôn cùng số
entry. Head của `u_strbfifo` là strobe của beat đang ghi. Có assertion kiểm việc này.

**Hỏi:** Sao cần arbiter?
**Đáp:** Macro chỉ có một port, mỗi cycle một truy cập. Round-robin cho write và read
thay phiên khi cả hai cùng xin.

**Hỏi:** Sao `rdata` phải qua `RFIFO`?
**Đáp:** Master có thể chưa sẵn sàng nhận (`rready` = 0). Read chỉ được issue khi
`RFIFO` còn chỗ, nên data đọc ra luôn có chỗ chứa.

## 4. Giải thích từng bảng

### Revision history (bảng không đánh số)

Lịch sử phiên bản: Version, Date, Author, Reviewer, Description of change. Dòng đáng
chỉ là V2.2: thêm wrapper interface, strobe FIFO, timing, reset, tie-offs, và sửa hình
cùng macro address. Lý do từng thay đổi nằm trong `QNSC_RAM_DECISIONS.md`.

### Table 1-1. Memory map, regions behind AXI_M1 and AXI_M2

Bảng cho biết địa chỉ nào tới RAM. Bảng được sinh tự động từ `util/qsoc_contract.yml`.

- **Cột:** Base, Size, Region (tên vùng), Port (cổng S_BUS), Kind, Note.
- **Dòng đáng chỉ:** `isram_dbg` và `isram` là **một macro trên một port**. RAM thấy một
  vùng 64 KiB; 4 KiB đầu chỉ là quy ước cho debug window.

**Hỏi:** Sao tách `ISRAM` và `DSRAM`?
**Đáp:** Hai macro trên hai port khác nhau, nên stack tràn không đè được chương trình
đang chạy. Chip không có MPU nên đây là cách bảo vệ duy nhất.

**Hỏi:** Truy cập `0x2001_0000` thì sao?
**Đáp:** Không thuộc vùng nào, S_BUS trả `DECERR`. RAM không bao giờ thấy nó.

### Table 4-1. Upstream IP used

Bảng ghi nguồn gốc mọi thứ không do em viết.

- **Cột:** From (nguồn), Module, Commit, Licence.
- **Dòng đáng chỉ:** controller ghim ở commit `503d7cd`, gồm `m_vlsi_axi4_sram` và bốn
  sub-module (`m_vlsi_axfsm`, `m_vlsi_fifo`, `m_vlsi_arbiter`, `m_vlsi_sram_misc`).
  Macro là của PDK SMIC 28 nm.

**Hỏi:** Sao ghim commit?
**Đáp:** Để regression 46 test của IP chạy lại được y nguyên. Verification còn kiểm
file `rtl/` trong repo khớp commit này.

### Table 5-1. RAM interface

Bảng port của wrapper: phía S_BUS, phía macro, clock và reset.

- **Cột:** Signal, Dir (in/out), Width, Description.
- **Dòng đáng chỉ:**
  - Các dòng handshake định nghĩa luôn `ready`/`valid` bằng trạng thái FIFO, ví dụ
    `bvalid` = `BFIFO` không rỗng.
  - `i_bus_axi_wstrb`: 4 bit, đi vào `u_strbfifo`.
  - `i_bus_axi_wlast`: có nối nhưng không dùng (Table 10-1).
  - `bresp`, `rresp`: luôn `00`, OKAY.
  - `o_sram_addr` 14 / 13 bit là **word address**; `o_sram_bwe` = 0 khi không ghi;
    `i_sram_rdata` được lấy mẫu một cycle sau `o_sram_oe`.

**Hỏi:** Sao không có `AxSIZE`?
**Đáp:** IP không có port đó; địa chỉ luôn tăng 4 byte. Xem Table 10-1 và Table 7-3.

**Hỏi:** Reset đồng bộ hay bất đồng bộ?
**Đáp:** `i_rst_n_mem` là asynchronous, active-low.

### Table 5-2. RAM parameters

Bảng tham số của hai instance, cố định lúc elaboration. Khối không có register.

- **Cột:** Parameter, giá trị cho `ISRAM`, giá trị cho `DSRAM`, Meaning.
- **Dòng đáng chỉ:** chỉ `PARA_SRAM_DEPTH` khác nhau (16384 so với 8192). Nó quyết định
  độ rộng `o_sram_addr` = `$clog2(PARA_SRAM_DEPTH)`. `PARA_ID_WD` = 7 lấy từ HAS Table 5-1.

**Hỏi:** Sao `PARA_ID_WD` phải là 7?
**Đáp:** Phải bằng ID width của master port S_BUS, nếu không `bid`/`rid` trả về không
khớp request.

**Hỏi:** Sao `PARA_FIFO_DEPTH` phải là lũy thừa của 2?
**Đáp:** FIFO của IP dùng con trỏ có thêm một bit MSB để phân biệt full và empty, nên
depth phải là 2^n.

### Table 7-1. FIFO buffers

Bảng mô tả sáu FIFO: năm của IP và một `STRBFIFO` của wrapper.

- **Cột:** FIFO, Width (bit), Contents, Push (khi nào ghi vào), Pop (khi nào lấy ra).
- **Dòng đáng chỉ:**
  - `WFIFO` và `STRBFIFO` push cùng `wvalid & wready`; pop cùng lúc (write grant chính là
    `o_sram_we`). Đây là lý do chúng luôn khớp nhau.
  - `AWFIFO`, `ARFIFO` nhận **một entry mỗi beat**, không phải mỗi burst.
  - `BFIFO` chỉ push ở beat last, vì một burst chỉ có một B response.
  - `RFIFO` push **cycle sau** read issue, vì macro trả data sau 1 cycle.

**Hỏi:** Width `ADDR + ID + 1` là gì?
**Đáp:** 32 bit address, 7 bit ID, 1 bit last flag.

**Hỏi:** Sao chỉ một read in flight?
**Đáp:** Read mới chỉ issue khi không có read pending. Đơn giản, đổi lại read burst chỉ
được 1 beat mỗi 2 cycle (Table 7-2).

### Table 7-2. Timing at the block ports, no contention, FIFOs empty

Bảng latency và throughput đo tại port của khối, khi không tranh chấp và FIFO rỗng.

- **Cột:** Quantity (đại lượng), Value (số cycle).
- **Dòng đáng chỉ, đếm từng cycle:**
  - Read 4 cycle: 0 AR handshake → 1 FSM đẩy `ARFIFO` → 2 read issue (`oe`) → 3 data vào
    `RFIFO` → 4 `rvalid`.
  - Write 3 cycle: 0 AW và W handshake → 1 FSM đẩy `AWFIFO` → 2 write grant, ghi macro,
    đẩy `BFIFO` → 3 `bvalid`.
  - Address handshake N + 2 cycle: 1 cycle handshake, N cycle phát beat, 1 cycle quay về idle.

**Hỏi:** Sao write burst nhanh gấp đôi read burst?
**Đáp:** Write không phải chờ data quay về. Read phải chờ một read xong mới issue read sau.

**Hỏi:** 4 cycle ở 20 MHz là bao nhiêu?
**Đáp:** 200 ns.

### Table 7-3. Burst address generation

Bảng cách address FSM tính địa chỉ beat kế tiếp theo `AxBURST`.

- **Cột:** `AxBURST`, Next address.
- **Dòng đáng chỉ:** `WRAP` và reserved đều ra `(addr + 4) & ~3`. Phép này căn lề địa chỉ,
  **không wrap**. Với địa chỉ đầu căn 4 byte, WRAP cho kết quả y như INCR.
- **Ghi thêm:** beat đầu dùng `AxADDR` nguyên; bước tăng luôn 4 byte bất kể `AxSIZE`;
  beat last do counter nạp từ `AxLEN` đánh dấu.

**Hỏi:** Test `wrap_*` của IP pass, sao nói WRAP sai?
**Đáp:** Reference model của IP tính cùng công thức với RTL, nên nó đồng ý với design
chứ không đồng ý với AXI.

**Hỏi:** Truy cập single beat không căn lề thì sao?
**Đáp:** Bit `[1:0]` không tới macro, nên nó trúng word chứa địa chỉ đó; khi ghi, `WSTRB`
chọn byte nào được ghi.

### Table 8-1. The two instances

Bảng so sánh `ISRAM` và `DSRAM`.

- **Cột:** Instance, Port, `PARA_SRAM_DEPTH`, `o_sram_addr` (bit address nào ra macro).
- **Dòng đáng chỉ:** 16384 word × 4 byte = 64 KiB, nên cần 14 bit `[15:2]`. 8192 × 4 =
  32 KiB, 13 bit `[14:2]`.

**Hỏi:** Có alias không?
**Đáp:** Không. Decode window bằng đúng cỡ macro, nên mỗi địa chỉ được route tới chọn đúng
một word.

### Table 9-1. Functions this block does not provide

Bảng nói rõ khối **không** làm gì, và ai làm thay.

- **Cột:** Function, Where it lives.
- **Dòng đáng chỉ:**
  - Address decode và `DECERR`: ở S_BUS.
  - `WRAP` và narrow burst: không ai làm, master không được phát.
  - SECDED, exclusive access: không có.
  - Nội dung `ISRAM`: ROM bootloader hoặc host qua SYSDBG (flow C).

**Hỏi:** Narrow burst là gì, sao sai?
**Đáp:** Là burst nhiều beat với `AxSIZE` dưới 4 byte. Khối luôn tăng 4, nên các beat
sau trỏ sai địa chỉ.

**Hỏi:** Không có SECDED thì lỗi bit ra sao?
**Đáp:** Không phát hiện được; `RRESP` vẫn là OKAY.

### Table 10-1. Tie-offs

Bảng các port nối cố định hoặc để hở, và lý do.

- **Cột:** Port, Tied to, Why.
- **Dòng đáng chỉ:**
  - `awsize`, `arsize`, `prot`, `cache`, `lock`, `qos` từ S_BUS: để hở, vì khối không có
    chức năng tương ứng.
  - `i_wlast`: nối nhưng bên trong không dùng; beat last lấy từ `AxLEN`.
  - Chân margin, retention, test của macro: theo databook, retention và test tắt.

**Hỏi:** Sao phải ghi chân macro vào spec?
**Đáp:** Model mô phỏng không có các chân đó, nên nối sai vẫn pass simulation và chỉ hỏng
trên silicon.

### Table 11-1. Requirements on other owners

Bảng việc người khác phải làm để RAM chạy đúng.

- **Cột:** Item (yêu cầu), Owner (ai chịu), What it blocks (hỏng gì nếu thiếu).
- **Dòng đáng chỉ:**
  - CPU2AXI mang byte enable ra `wstrb`: thiếu thì mọi store dưới word đều hỏng.
  - **Câu hỏi còn mở với DMA owner:** DMA có phát WRAP hoặc narrow burst vào RAM không? Nếu
    có, đặt `axi_burst_unwrap` trước khối.
  - Firmware để trống 4 KiB đầu `ISRAM` cho debug window.
- **Còn mở ngoài bảng:** timing và area của hai instance sau synthesis.

**Hỏi:** `axi_burst_unwrap` là gì?
**Đáp:** Module của `pulp-platform/axi`, đã dùng trong S_BUS. Nó tách WRAP thành các burst
INCR.

**Hỏi:** Ibex hay SYSDBG có phát WRAP không?
**Đáp:** Không. CPU2AXI và SYSDBG chỉ phát single beat; chỉ DMA có thể phát burst.

### Table A-1. Acronyms

Bảng viết tắt: Acronym và Description. Đáng nhớ: BWE là byte write enable, `WSTRB` là
byte enable của AXI, SECDED là Single Error Correct, Double Error Detect.

### Table B-1. First review

Bảng câu hỏi review và trả lời: Item, Reviewer, Response.

- Thầy chê bản cũ dài và lặp gây sai: viết lại chỉ còn spec, memory map sinh từ contract.
- Thiếu `WSTRB` không phải lỗi IP: README của IP ghi đó là giới hạn; wrapper bổ sung.
- Bốn test `wrap_*` pass không chứng minh WRAP đúng (xem Table 7-3).
- ROM là khối riêng `design/rom`, dùng cùng controller với kênh write để idle.

**Hỏi:** Nếu ROM dùng cùng controller, sao không gộp chung tài liệu?
**Đáp:** ROM là block khác, thư mục khác, không có write. Tài liệu này chỉ nói `ISRAM`
và `DSRAM`.
