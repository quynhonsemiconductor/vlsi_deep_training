# Thuyết trình RAM (ISRAM / DSRAM) — bản đọc

**Khớp tài liệu:** `QNSC_RAM_MAS` V2.2 · **Ngày:** 2026-09-24

## 1. RAM là gì

`ISRAM` và `DSRAM` là hai RAM on-chip của QSOC. Mỗi cái là một instance của
`m_qnsc_wrap_axi4_sram`: IP `AXI4-SRAM-CONTROLLER` giữ nguyên, cộng thêm một write-strobe
FIFO, đặt trước một SMIC 28 nm single-port SRAM macro. `ISRAM` 64 KiB trên `AXI_M1` chứa
chương trình; `DSRAM` 32 KiB trên `AXI_M2` chứa stack, heap và biến. Khối không decode
địa chỉ, không bao giờ trả error response, và không có register.

## 2. Flow end-to-end

### Câu chuyện chính: CPU store một byte (`sb` vào `0x3000_0001`, tức `DSRAM`)

Cycle 0–3 là cycle đo tại port của RAM, khi không tranh chấp và FIFO rỗng (Table 7-2).

**Bước 1 — Ibex phát store.** *Ở đâu:* LSU của Ibex. *Làm gì:* chạy lệnh `sb`, phát
địa chỉ `0x3000_0001`, data, và byte enable `0010` vì byte nằm ở lane 1. *Đi tiếp:*
request cùng byte enable sang CPU2AXI. *Phụ thuộc:* không có. *(Vì sao: RV32 có `sb` và
`sh`, và C code nào đụng `uint8_t`, field của packed struct hay string cũng sinh ra chúng.
Không có byte enable thì store ghi cả word và phá ba byte bên cạnh mà không báo lỗi, vì
RAM luôn trả OKAY.)*

**Bước 2 — CPU2AXI đổi sang AXI.** *Ở đâu:* CPU2AXI. *Làm gì:* đổi request thành một
AXI4 write một beat (`awlen` = 0). *Đi tiếp:* AW và W (có `wstrb` = `0010`) vào
`S_BUS`. *Phụ thuộc:* CPU2AXI phải đưa byte enable ra `wstrb` (Table 11-1), nếu không
thì mọi store dưới word đều hỏng. *(Vì sao: CPU2AXI dựa trên `axi_from_mem`, chỉ phát
single beat, và SYSDBG cũng vậy; `WRAP` chỉ dùng cho cache-line fill, nên em không cần hỗ
trợ nó. Chỉ DMA có thể phát burst; nếu nó phát `WRAP` thì đặt `axi_burst_unwrap` phía
trước, không phải sửa IP.)*

**Bước 3 — S_BUS decode.** *Ở đâu:* `S_BUS`. *Làm gì:* `0x3000_0001` thuộc vùng `dsram`
(Table 1-1). *Đi tiếp:* AW và W ra cổng `AXI_M2`, vào `i_bus_axi_aw*` và `i_bus_axi_w*`
của `DSRAM`. *Phụ thuộc:* decode window bằng đúng cỡ macro, `DECERR` cho địa chỉ ngoài
bản đồ, ID width 7 bằng `PARA_ID_WD` (Table 11-1). *(Vì sao: RAM không decode và luôn
trả OKAY, nên chỉ `S_BUS` mới trả được `DECERR`. Window bằng đúng cỡ macro vì window lớn
hơn sẽ làm địa chỉ alias im lặng vào một word khác.)*

**Bước 4 — AW handshake, cycle 0.** *Ở đâu:* `u_axfsm_wr`. *Làm gì:* nhận `awaddr`,
`awlen`, `awid`, `awburst`. *Đi tiếp:* cycle 1 đẩy một entry {address, ID, last = 1} vào
`AWFIFO`. *Phụ thuộc:* `awready` = FSM idle và `AWFIFO` chưa full. *(Vì sao: mỗi channel
có FIFO riêng nên handshake AXI tách khỏi timing của SRAM, và transfer liên tiếp không bị
stall. `awready` tính từ FIFO nên handshake không bao giờ hứa một beat mà FIFO không nhận
được.)*

**Bước 5 — W handshake, cũng cycle 0.** *Ở đâu:* `WFIFO` trong IP và `u_strbfifo` trong
wrapper. *Làm gì:* cùng một điều kiện `wvalid & wready`, `wdata` vào `WFIFO` và `wstrb`
vào `u_strbfifo`. *Đi tiếp:* hai head chờ `u_sram_misc`. *Phụ thuộc:* `wready` = `WFIFO`
chưa full. `wlast` không dùng; beat last lấy từ `AxLEN`. *(Vì sao: IP không có `WSTRB`,
và em giữ IP nguyên để regression 46 test của nó chạy lại y nguyên; nên strobe đi một FIFO
riêng, push và pop cùng lúc với `WFIFO`. Phải là FIFO chứ không phải một register chung,
vì trong một burst mỗi beat có thể có strobe khác nhau.)*

**Bước 6 — Xin quyền, cycle 2.** *Ở đâu:* `u_sram_misc` và `u_arbiter`. *Làm gì:*
`AWFIFO` và `WFIFO` đều có data, nên `u_sram_misc` bật `req_write`. *Đi tiếp:* arbiter trả
`write_en` về `u_sram_misc`. *Phụ thuộc:* request đơn lẻ được cấp ngay cycle đó; nếu có
read cùng lúc thì round-robin toggle chọn một, và toggle lật sau mỗi grant. *(Vì sao:
macro single port, mỗi cycle chỉ một truy cập, nên read và write phải chia nhau. Round-robin
để không bên nào starve bên kia.)*

**Bước 7 — Ghi macro, cycle 2.** *Ở đâu:* `u_sram_misc`, wrapper, macro. *Làm gì:* pop
`AWFIFO` và `WFIFO`; `o_sram_we` = 1, `o_sram_addr` = byte address `[14:2]` (word 0),
`o_sram_wdata` = data. Chính `o_sram_we` pop `u_strbfifo`, và `o_sram_bwe` = head =
`0010`. *Đi tiếp:* macro chỉ ghi `wdata[15:8]`; ba byte còn lại giữ nguyên. *Phụ thuộc:*
macro có byte write enable; `STRBFIFO` và `WFIFO` luôn cùng số entry (7.3); chân macro
tie đúng (Table 10-1). *(Vì sao: macro thật đánh địa chỉ theo word, nên chỉ lấy `[14:2]`,
bỏ `[1:0]`. Byte enable ghi một byte trong một cycle, đúng ý AXI; phương án read-modify-write
thì chậm hơn và phải khoá với read cùng địa chỉ.)*

**Bước 8 — Sinh B, cycle 2 và 3.** *Ở đâu:* `u_sram_misc` và `BFIFO`. *Làm gì:* beat này
là last, nên đẩy {ID, `BRESP` = `00`} vào `BFIFO`. *Đi tiếp:* cycle 3, `bvalid` = `BFIFO`
không rỗng; `bid` và `bresp` ra `AXI_M2`. *Phụ thuộc:* `BFIFO` pop khi `bvalid & bready`.
*(Vì sao: `BRESP` luôn OKAY vì không có SECDED, RAM không có lỗi nào để phát hiện. Nếu sau
này thêm integrity thì response thành tín hiệu thật; `RFIFO` đã có sẵn 2 bit `RRESP`.)*

**Bước 9 — B về Ibex.** *Ở đâu:* `S_BUS` rồi CPU2AXI. *Làm gì:* `S_BUS` trả B theo ID về
CPU2AXI; CPU2AXI báo Ibex store đã xong. *Phụ thuộc:* `bid` đúng ID của request. *(Vì sao:
`S_BUS` nới rộng ID của master để giữ chúng unique, nên `PARA_ID_WD` phải bằng ID width ở
master port, tức 7 bit.)*

**Kết thúc:** byte đã nằm trong word 0 của macro từ cycle 2. Ibex nhận B với `BRESP` =
OKAY. Tại port RAM, `bvalid` đến 3 cycle sau AW handshake.

### CPU load (`lw` từ `0x2000_1000`, tức `ISRAM`)

**Bước 1 — Ibex phát load.** *Ở đâu:* LSU của Ibex. *Làm gì:* phát địa chỉ đọc. *Đi
tiếp:* sang CPU2AXI, thành một AR một beat vào `S_BUS`. *Phụ thuộc:* không có. *(Vì sao
một beat: như bước 2 của store.)*

**Bước 2 — S_BUS decode.** *Ở đâu:* `S_BUS`. *Làm gì:* `0x2000_1000` thuộc `isram`. *Đi
tiếp:* AR ra `AXI_M1` vào `ISRAM`. *Phụ thuộc:* như bước 3 của store. *(Vì sao tách
`ISRAM` và `DSRAM`: `S_BUS` là crossbar, nên CPU fetch từ `ISRAM` không phải tranh với DMA
hay SYSDBG đang truy cập `DSRAM`. Thêm nữa, một con trỏ data lạc chỉ ghi vào `DSRAM`, không
đè được chương trình.)*

**Bước 3 — AR handshake, cycle 0.** *Ở đâu:* `u_axfsm_rd`. *Làm gì:* nhận `araddr`,
`arlen`, `arid`. *Đi tiếp:* cycle 1 đẩy {address, ID, last} vào `ARFIFO`. *Phụ thuộc:*
`arready` = FSM idle và `ARFIFO` chưa full. *(Vì sao: như bước 4 của store.)*

**Bước 4 — Read issue, cycle 2.** *Ở đâu:* `u_sram_misc` và `u_arbiter`. *Làm gì:*
`req_read`, được cấp quyền, pop `ARFIFO`. *Đi tiếp:* `o_sram_oe` = 1 và `o_sram_addr` =
`[15:2]` vào macro. *Phụ thuộc:* `ARFIFO` có data, `RFIFO` chưa full, không có read nào
đang pending. *(Vì sao: IP chỉ cho một read in flight, và em giữ IP nguyên như bước 5
của store. Cái giá là read burst chỉ 1 beat mỗi 2 cycle, và đây là chỗ xem lại đầu tiên nếu
RAM thành bottleneck; `[15:2]` là word address như bước 7 của store.)*

**Bước 5 — Data ra macro, cycle 3.** *Ở đâu:* macro rồi `u_sram_misc`. *Làm gì:* macro trả
`rdata` sau 1 cycle; `u_sram_misc` đẩy {data, ID, `RRESP` = `00`, last} vào `RFIFO`. *Đi
tiếp:* `RFIFO`. *Phụ thuộc:* `i_sram_rdata` được lấy mẫu một cycle sau `o_sram_oe`.
*(Vì sao: read chỉ được issue khi `RFIFO` còn chỗ, nên data ra sau 1 cycle luôn có chỗ
chứa, kể cả khi master đang giữ `rready` thấp.)*

**Bước 6 — R ra bus, cycle 4.** *Ở đâu:* `RFIFO`. *Làm gì:* `rvalid` = `RFIFO` không rỗng.
*Đi tiếp:* `rdata`, `rid`, `rresp`, `rlast` ra `AXI_M1`, qua `S_BUS`, CPU2AXI, về Ibex.
*Phụ thuộc:* `RFIFO` pop khi `rvalid & rready`. *(Vì sao: mọi `valid` và `ready` phía AXI
đều tính từ số entry trong FIFO, nên back-pressure tự lan ngược mà không cần timer hay
counter nào.)*

**Kết thúc:** data vào register của Ibex. Tại port RAM, `rvalid` đến 4 cycle sau AR
handshake. Instruction fetch từ `ISRAM` cũng đi đúng đường này.

### ISRAM có nội dung thế nào lúc boot

**Bước 1 — Bật nguồn.** *Ở đâu:* SCRC và `ISRAM`. *Làm gì:* SCRC thả `i_rst_n_mem`;
controller sẵn sàng. *Đi tiếp:* chờ ghi. *Phụ thuộc:* macro không có reset, nên array
chưa có chương trình nào. *(Vì sao phải nạp: QSOC không có flash, nên chương trình phải
được nạp vào RAM và chạy từ RAM. Đó là lý do có `ISRAM`.)*

**Bước 2a — Normal boot (`DBG_EN` = 0).** *Ở đâu:* ROM bootloader chạy trên Ibex. *Làm
gì:* nhận ảnh qua UART0. *Đi tiếp:* ghi ảnh vào `ISRAM` từ `0x2000_1000`; mỗi lần ghi là
câu chuyện store ở trên, trên `AXI_M1`. *Phụ thuộc:* firmware link ảnh ở `0x2000_1000`
và để trống 4 KiB đầu (Table 11-1). *(Vì sao: 4 KiB đầu là debug window của SYSDBG. Nó chỉ
là một quy ước địa chỉ, không tốn phần cứng nào, nên firmware phải tránh ra.)*

**Bước 2b — Debug boot (`DBG_EN` = 1).** *Ở đâu:* host, qua JTAG vào SYSDBG. *Làm gì:*
CPU bị giữ reset; SYSDBG là AXI4 manager trên `AXI_S0`. *Đi tiếp:* qua `S_BUS` vào
`AXI_M1`, ghi debug window `0x2000_0000`–`0x2000_0FFF` rồi ảnh từ `0x2000_1000`. *Phụ
thuộc:* SYSDBG chỉ phát write một beat, nên RAM thấy AXI4 write bình thường. *(Vì sao: đây
là đường nạp thứ hai, dùng khi nội dung ROM đáng nghi. SYSDBG dùng AXI master sẵn có của nó,
nên RAM không cần thêm port hay logic gì.)*

**Bước 3 — Chạy.** *Ở đâu:* Ibex. *Làm gì:* bootloader nhảy vào `0x2000_1080`, hoặc host
thả CPU. *Đi tiếp:* Ibex fetch lệnh từ `ISRAM`, đúng câu chuyện load.

**Kết thúc:** chương trình nằm trong `ISRAM` và Ibex chạy từ đó.

### Watchdog hoặc software reset

**Bước 1 — Assert.** *Ở đâu:* SCRC. *Làm gì:* watchdog hoặc software (hoặc power-on) gây
reset. *Đi tiếp:* `i_rst_n_mem` xuống thấp bất đồng bộ, vào RAM. *Phụ thuộc:* không có.
*(Vì sao chỉ ba nguồn: review Day005 chốt power-on, watchdog và software, và bỏ debug
reset.)*

**Bước 2 — Xoá controller.** *Ở đâu:* controller và `u_strbfifo`. *Làm gì:* mọi flop về 0:
FSM về `S_IDLE`, FIFO rỗng, arbiter toggle và read-pending = 0. *Đi tiếp:* transaction
đang dở bị bỏ, không có response. *(Vì sao bị bỏ: FIFO pointer về 0, nên beat nào đang chờ
trong FIFO cũng mất theo.)*

**Bước 3 — Release.** *Ở đâu:* SCRC. *Làm gì:* thả `i_rst_n_mem` đồng bộ với clock. *Đi
tiếp:* `awready`, `arready`, `wready` = 1; `bvalid`, `rvalid` = 0. RAM nhận request mới.

**Bước 4 — Macro.** *Ở đâu:* SRAM macro. *Làm gì:* không gì cả. Array không có reset, không
có clear-on-reset. *(Vì sao: macro không có reset, và từ V2.1 spec chốt không thêm
clear-on-reset, nên chương trình trong `ISRAM` sống qua watchdog và software reset.)*

**Kết thúc:** controller như mới, nội dung `ISRAM` và `DSRAM` còn nguyên. Chỉ mất nguồn
mới xoá nội dung.

| IP liên quan | RAM cần gì từ IP đó |
|---|---|
| Ibex | Phát byte enable cho `sb`, `sh` |
| CPU2AXI | Mang byte enable ra `wstrb` |
| S_BUS | Decode window đúng bằng cỡ macro, `DECERR` cho địa chỉ lạ, ID width 7 |
| DMA | Không phát `WRAP` hay narrow burst vào RAM (câu hỏi còn mở) |
| ROM bootloader + UART0 | Nạp `ISRAM` ở normal boot |
| SYSDBG | Nạp debug window và ảnh ở debug boot |
| Firmware | Để trống 4 KiB đầu `ISRAM`, link ảnh ở `0x2000_1000` |
| SCRC, cluster `mem` | `i_clk_mem` 20 MHz không bao giờ gate; `i_rst_n_mem` assert bất đồng bộ, release đồng bộ |
| Physical design | Tie chân margin, retention, test của macro (Table 10-1) |

## 3. Giải thích từng hình

### Figure 3-1. The RAM block: wrapper, unmodified controller and macro. Heavy outline: the strobe FIFO QSOC adds

Hình này trả lời: trong khối RAM có gì, và phần nào QSOC thêm vào.

Em đi từ trái sang phải. Góc trên bên trái là ô ghi "i_clk_mem, i_rst_n_mem": clock và
reset từ cluster `mem`. Mũi tên từ ô này đi vào khung nét đứt lớn nhất.

Bên dưới là khung nét đứt ghi "S_BUS AXI_M1 (ISRAM) or AXI_M2 (DSRAM)": đây là cổng
master của bus hệ thống, nhìn từ phía RAM. Trong khung có năm ô **W**, **AW**, **AR**,
**R**, **B**, là năm channel AXI. W, AW, AR là chiều đi vào RAM; R và B là chiều quay về.

Bước sang phải là khung nét đứt lớn ghi "m_qnsc_wrap_axi4_sram": wrapper của QSOC. Bên
trong là khung nét đứt nhỏ hơn ghi "u_ctrl | m_vlsi_axi4_sram (IP, unmodified)": IP
controller, em không sửa dòng nào.

Từ ô **W** có mũi tên ghi `wdata` đi vào ô **WFIFO**, FIFO chứa write data. Từ **WFIFO**
mũi tên đi thẳng vào ô lớn **u_sram_misc**.

Cũng từ ô **W** có một nhánh rẽ lên trên, ra khỏi khung IP, vào ô viền đậm ghi
"u_strbfifo, wstrb, 4 bit x 8". Đây là phần duy nhất QSOC thêm: FIFO 4 bit, 8 entry, chứa
`wstrb`, vì IP không có input `WSTRB`. Từ ô này có mũi tên ghi `bwe[3:0]` đi thẳng sang
phải, vào macro.

Từ ô **AW** mũi tên vào ô **u_axfsm_wr**, address FSM của write: nhận handshake và sinh
địa chỉ từng beat. Từ đó vào ô **AWFIFO**, rồi vào **u_sram_misc**. Ô **AR** giống hệt:
qua **u_axfsm_rd**, vào **ARFIFO**, rồi vào **u_sram_misc**.

Ô **u_sram_misc** ghi "FIFO pop, SRAM mux, R and B generation". Nó pop các FIFO, chọn địa
chỉ của write hay read để đưa xuống SRAM, và sinh response R, B. Phía dưới, mũi tên ghi
`req_write, req_read` đi xuống ô **u_arbiter** ghi "round-robin". Arbiter trả lại mũi tên
ghi `arb_sel, write_en` đi lên **u_sram_misc**: đó là grant.

Từ đỉnh **u_sram_misc** có mũi tên ghi `o_sram_we (pop)` quay lên **u_strbfifo**. Mỗi
lần ghi macro, `o_sram_we` pop strobe ở head ra, nên `bwe` đúng beat đang ghi.

Sang phải, **u_sram_misc** có hai mũi tên ra khỏi wrapper, vào ô **SRAM macro**. Mũi tên
ghi `addr[15:2] / [14:2]`: word address, `[15:2]` cho `ISRAM`, `[14:2]` cho `DSRAM`. Mũi
tên ghi `wdata, we, oe`: data ghi, write enable, và read enable.

Ô cuối cùng ghi "SRAM macro, single port, 1-cycle read, no reset". Single port nên cần
arbiter. 1-cycle read nghĩa là data ra sau một cycle. No reset nghĩa là nội dung sống qua
mọi reset. Từ macro có mũi tên ghi `rdata` quay về **u_sram_misc**.

Cuối cùng là đường về. Từ **u_sram_misc** mũi tên sang trái vào ô **RFIFO**, rồi ra ô
**R**. Và từ **u_sram_misc** vào ô **BFIFO**, rồi ra ô **B**.

**Tóm lại:** request vào qua FIFO, `u_sram_misc` xin arbiter rồi lái một macro single
port, response quay về qua `RFIFO` và `BFIFO`. Toàn bộ controller là IP nguyên bản. QSOC
chỉ thêm `u_strbfifo` để đưa `wstrb` thành byte enable của macro.

**Hỏi:** Sao `u_strbfifo` nằm ngoài controller?
**Đáp:** IP không có input `WSTRB`, và em giữ IP nguyên vẹn. Nên wrapper thêm một FIFO
riêng chạy song song với `WFIFO`.

**Hỏi:** Làm sao chắc strobe khớp đúng beat data?
**Đáp:** `u_strbfifo` có `PARA_DEPTH` = `$clog2(PARA_FIFO_DEPTH)`, nên cũng 8 entry như
`WFIFO`. Hai FIFO push cùng điều kiện, pop cùng lúc, nên luôn cùng số entry. Có assertion
kiểm việc này.

**Hỏi:** Arbiter chọn thế nào khi write và read cùng xin?
**Đáp:** Một round-robin toggle chọn một bên, và toggle lật sau mỗi grant. Request đơn lẻ
được cấp ngay trong cycle nó xuất hiện.

**Hỏi:** Sao `rdata` phải qua `RFIFO`?
**Đáp:** Master có thể chưa sẵn sàng nhận. Read chỉ được issue khi `RFIFO` còn chỗ, nên
data đọc ra luôn có chỗ chứa.

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

## 5. Vì sao con số này

| Con số | Ở đâu (bảng/hình) | Vì sao | Nếu khác thì sao |
|---|---|---|---|
| Data width 32 (`PARA_DATA_WD`, `wdata`, `rdata`, `o_sram_wdata`) | Table 5-1, 5-2, 7-1 | Ibex là core RV32, và data width của `S_BUS` là 32 bit cho cả chip (contract `data_width`). `PARA_DATA_WD` lấy từ geometry của `S_BUS`. | Không khớp `S_BUS` thì không nối thẳng được vào `AXI_M1`/`AXI_M2`. |
| Address width 32 (`PARA_ADDR_WD`, `awaddr`, `araddr`) | Table 5-1, 5-2 | Là width của AXI address bus cho cả chip (contract `addr_width`), không nói gì về dung lượng. Dung lượng do `PARA_SRAM_DEPTH` quyết định. | Hẹp hơn thì không khớp `S_BUS`. |
| ID width 7 (`PARA_ID_WD`, `awid`, `arid`, `bid`, `rid`) | Table 5-1, 5-2, 11-1; Revision history | Bằng ID width ở master port của `S_BUS`, theo HAS Table 5-1. `S_BUS` nới rộng ID của master để giữ chúng unique. | `bid`/`rid` bị cắt, response không khớp request. |
| `PARA_LEN_WD` = 8, `awlen`/`arlen` 8 bit, burst tới 256 beat | Table 5-1, 5-2 | AXI4 định nghĩa `AxLEN` 8 bit = beat trừ 1, nên tối đa 256 beat cho INCR; burst FIXED bị AXI4 giới hạn 16 beat. | Hẹp hơn thì burst dài của master bị hiểu sai độ dài. |
| `AxBURST` 2 bit: `00`, `01`, `10`, `11` | Table 5-1, 7-3 | Mã hoá của AXI: FIXED, INCR, WRAP, reserved. `10` và `11` vẫn được nhận nhưng chỉ căn lề địa chỉ (7.4). | Không áp dụng; đây là chuẩn AXI. |
| `wstrb` 4 bit; `bwe[3:0]`; bit *n* ghi `wdata[8n+7:8n]` | Table 5-1, 7-1; Figure 3-1 | AXI dùng một bit strobe cho mỗi byte: 32 / 8 = 4. Bit *n* ứng với byte lane *n*. | Không áp dụng; width do data width quyết định. |
| `u_strbfifo` "4 bit x 8" | Figure 3-1, Table 7-1 | 4 bit là `wstrb`. 8 entry vì `PARA_DEPTH` = `$clog2(PARA_FIFO_DEPTH)`, bằng đúng `WFIFO`, để hai FIFO luôn cùng số entry. | Khác depth `WFIFO` thì strobe có thể lệch beat. |
| `PARA_FIFO_DEPTH` = 8 | Table 5-2 | Giá trị mặc định của IP, không có lý do bắt buộc. Sâu hơn thì hấp thụ burst dài không bị back-pressure, nhưng tốn register. | Nhỏ hơn: back-pressure sớm hơn. Lớn hơn: tốn area. |
| `PARA_FIFO_DEPTH` là lũy thừa của 2 | Table 5-2 | FIFO của IP dùng con trỏ `$clog2(depth)` bit cộng một bit MSB để phân biệt full và empty. | Số không phải 2^n thì FIFO thật có số entry làm tròn lên 2^n, khác con số ghi. |
| 6 FIFO (5 của IP + `STRBFIFO`) | Table 5-2, 7-1 | Năm channel AXI (AW, W, AR, R, B), mỗi channel một FIFO. `STRBFIFO` là cái thứ sáu, vì IP không có `WSTRB`. | Không có FIFO thì handshake AXI dính vào timing của SRAM. |
| Width FIFO: `ADDR + ID + 1` = 40, `DATA` = 32, `DATA + ID + 2 + 1` = 42, `ID + 2` = 9 | Table 7-1 | Cộng các field mỗi FIFO phải chở: address 32, ID 7, last flag 1, `RRESP`/`BRESP` 2. | Thiếu bit thì mất field tương ứng. |
| `ISRAM` 64 KiB | Table 1-1, 8-1, A-1 | Phải chứa cả firmware vì không có flash. Ước lượng firmware 22–34 KiB; 32 KiB chỉ còn 28 KiB sau debug window, không đủ. Chọn dư rẻ hơn chọn thiếu. | 32 KiB: firmware có thể không vừa, phát hiện muộn lúc tích hợp. |
| `DSRAM` 32 KiB | Table 1-1, 8-1, A-1 | Theo HAS và memory map đã thống nhất, không có lý do bắt buộc được ghi. Nó chỉ chứa stack, heap và biến. | Đổi bằng `PARA_SRAM_DEPTH` và decode window, không sửa RTL. |
| `PARA_SRAM_DEPTH` 16384 / 8192 | Table 5-2, 8-1 | Tính thẳng: 64 KiB / 4 B = 16384 word; 32 KiB / 4 B = 8192 word. Đây là tham số duy nhất khác nhau giữa hai instance. | Đổi nó là đổi dung lượng; decode window phải đổi theo. |
| `o_sram_addr` 14 / 13 bit, `[15:2]` / `[14:2]` | Table 5-1, 8-1; Figure 3-1 | `$clog2(16384)` = 14, `$clog2(8192)` = 13. Bỏ `[1:0]` vì macro đánh địa chỉ theo word, 4 byte một word. | Nối byte address thẳng thì lệch hệ số 4, sai trên macro thật. |
| Base `0x2000_0000` / `0x3000_0000` | Table 1-1 | Mỗi vùng có một nibble `addr[31:28]` riêng: ROM `0x0`, `ISRAM` `0x2`, `DSRAM` `0x3`. Dễ nhận ra khi đọc trace. Con số cụ thể là quy ước theo HAS. | Không ảnh hưởng RAM; RAM bỏ qua bit trên word address. |
| Debug window 4 KiB ở `0x2000_0000`; ảnh chính ở `0x2000_1000` | Table 1-1, 11-1 | Cỡ 4 KiB theo HAS. Đặt ở đáy `ISRAM` vì tham số `Dm*` của Ibex chỉ phụ thuộc base, không đổi khi `ISRAM` lớn lên. Ảnh chính bắt đầu ngay sau đó. | Đặt ở đỉnh thì mỗi lần đổi `PARA_SRAM_DEPTH` phải build lại CPU. |
| `isram` 60 KiB | Table 1-1 | Tính thẳng: 64 KiB trừ 4 KiB debug window. | — |
| Decode window = cỡ macro (64 KiB, 32 KiB) | Table 1-1, 8-1 | Window lớn hơn macro thì địa chỉ vượt độ sâu alias im lặng vào word khác. Ngoài window, `S_BUS` trả `DECERR`. | Window lớn hơn: con trỏ lạc đọc sai data mà không có báo lỗi. |
| `AXI_M1`, `AXI_M2` | Table 1-1, 8-1, 11-1 | Chọn theo quy ước / theo HAS, không có lý do bắt buộc. | — |
| Clock 20 MHz | Table 5-1 | Một tần số cho cả chip (contract `clock_mhz`), không có PLL vì PDK không có analogue IP. | Không áp dụng; RAM không có ràng buộc tần số riêng trong MAS. |
| Response `00` OKAY (`bresp`, `rresp`, tie-off `2'b00`) | Table 5-1, 10-1 | Không có SECDED nên không có lỗi để báo; decode là việc của `S_BUS`. | Muốn báo lỗi thì phải thêm nguồn lỗi; `RFIFO` đã có 2 bit `RRESP`. |
| `o_sram_we` một cycle mỗi beat; `i_sram_rdata` lấy mẫu cycle sau `o_sram_oe`; "1-cycle read" | Table 5-1; Figure 3-1 | Macro single port, đọc mất một cycle: địa chỉ ở cycle này, data ở cycle sau. | Macro chậm hơn thì controller không khớp. |
| Single port | Figure 3-1 | Interface SRAM của IP chỉ có một địa chỉ chung cho read và write. | Vì thế cần `u_arbiter`, mỗi cycle một truy cập. |
| `rvalid` sau 4 cycle | Table 7-2 | Đếm từ RTL: 0 AR handshake, 1 FSM đẩy `ARFIFO`, 2 read issue, 3 data vào `RFIFO`, 4 `rvalid`. | Có tranh chấp hoặc FIFO không rỗng thì lâu hơn. |
| `bvalid` sau 3 cycle | Table 7-2 | 0 AW và W handshake, 1 FSM đẩy `AWFIFO`, 2 write grant và đẩy `BFIFO`, 3 `bvalid`. | Như trên. |
| Read burst 1 beat mỗi 2 cycle | Table 7-2 | IP chỉ cho một SRAM read in flight: issue một cycle, data cycle sau, rồi mới issue tiếp. | Đây là chỗ xem lại đầu tiên nếu RAM thành bottleneck. |
| Write burst 1 beat mỗi cycle | Table 7-2 | Write không chờ data quay về; mỗi cycle pop một cặp `AWFIFO`/`WFIFO`. | — |
| Address handshake 1 mỗi N + 2 cycle | Table 7-2 | FSM hai state: 1 cycle handshake, N cycle phát beat, 1 cycle quay về `S_IDLE`. | Burst ngắn thì overhead 2 cycle chiếm tỷ lệ lớn. |
| Bước địa chỉ `+ 4`; `(addr + 4) & ~3` | Table 7-3 | 4 = 32 / 8 byte; IP không có `AxSIZE`, nên luôn tăng 4. `& ~3` là cách IP tính WRAP: căn lề, không wrap. | Narrow burst hoặc WRAP thật sẽ ra địa chỉ sai (Table 9-1). |
| `AxSIZE` dưới 4 byte, `AxLEN` trên 0 | Table 9-1 | Định nghĩa narrow burst. Single beat thì vẫn đúng, vì `WSTRB` chọn byte và `[1:0]` không tới macro. | Các beat sau của narrow burst trỏ sai địa chỉ. |
| Commit `503d7cd`, "four sub-modules" | Table 4-1 | Ghim commit để regression 46 test chạy lại y nguyên và kiểm được file vendored. Bốn sub-module: `m_vlsi_axfsm`, `m_vlsi_fifo`, `m_vlsi_arbiter`, `m_vlsi_sram_misc`. | Không ghim thì không biết đang dùng bản RTL nào. |
| SMIC 28 nm | Table 4-1 | Công nghệ của dự án, theo HAS. | — |
| Bốn test `wrap_*` | Table B-1 | Số test WRAP có sẵn trong regression của IP; chúng pass vì reference model tính cùng công thức với RTL. | — |
| V2.0–V2.2, ngày 2026-09-23/24 | Revision history, Table B-1 | Chọn theo quy ước, không có lý do bắt buộc. | — |
