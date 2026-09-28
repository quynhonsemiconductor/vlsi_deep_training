# QNSC_I2C — design decisions and record

**This is not the specification.** That is [`QNSC_I2C_MAS.md`](QNSC_I2C_MAS.md).

The specification is written from the research report of Ong Bao Vinh, kept whole
below. The report analysed the core to the level of each FSM; its register map, SCL
formula and interrupt behaviour were re-checked against the vendored source and
hold. Its figures are not reproduced.

---

# 1. Research report to V3.0

| Change | Why |
|---|---|
| Upstream `apb_i2c` used unmodified: `TXCMD` (`0x18`), `RXCMD` (`0x1C`), `dma_last_i` and the two DMA request lines dropped | `QNSC_DMA_MAS` V3.0 has no hardware request. `RXCMD` also read with a side effect (a debugger read starts a bus transfer) and lagged one byte (report F6); without it, F1, F2 and F4 disappear |
| Open drain as two output enables to the IO MUX, no `1'bz` in the wrapper | Report F5: a tri-state inside core logic does not synthesise; the pad cell makes the line |
| Wrapper `m_qnsc_wrap_i2c`, `i_clk_peri`/`i_rst_n_peri`, `o_int_i2c`, 12-bit `PADDR`, no parameter | Naming Rule V1.1, `design/README.md` "Shared numbers"; the report used `m_qnsc_wrap_apb_i2c`, `i_clk_sys` and `P_APB_ADDR_WIDTH` |
| Prescaler table at 20 MHz | The report's example used 50 MHz; QSOC runs at 20 MHz (contract `meta.clock_mhz`). Values from the report's own formula |
| `APB_M11`, `INTMAP` line 3 | The report used `APB_S12`; the contract names the port `APB_M11` |
| `#1` delays and `timescale` (F8) | Harmless in synthesis; not a specification matter |

---

# Research report as issued

**QUY NHON SEMICONDUCTORS – QNSC**

**QSOC I2C Core IP  
Research Report**

*Báo cáo nghiên cứu Core IP apb_i2c và wrapper tích hợp m_qnsc_wrap_apb_i2c*

**Owner: Vinh (I2C Core IP — tích hợp P_BUS slot APB_S12, QSOC)**

Đối tượng: core pulp-platform/apb_i2c (lõi OpenCores I2C — R. Herveille) + bản vá DMA QSOC + wrapper m_qnsc_wrap_apb_i2c

Nguồn RTL: chosen_repos/08_I2C_apb_i2c/qsoc_dma_changes/

Phương pháp: phân tích tĩnh RTL (static RTL review) — chưa mô phỏng, chưa tổng hợp

Phiên bản v1 — 24/09/2026

> ***Cách đọc tài liệu:** mỗi đoạn lập luận kỹ thuật được theo sau bởi một khối “Diễn giải” (nền xanh nhạt, viền trái). Phần lập luận dành cho người thiết kế/kiểm chứng RTL; phần diễn giải tóm lại ý nghĩa bằng ngôn ngữ đơn giản để người nghe trình bày cũng nắm được kết quả.*

## 1. Bối cảnh và mục tiêu nghiên cứu

### 1.1 Bối cảnh: bus I2C

I2C (Inter-Integrated Circuit) là bus nối tiếp đồng bộ hai dây: SCL mang xung nhịp, SDA mang dữ liệu. Cả hai dây là **open-drain** với điện trở kéo lên bên ngoài. Vì mọi thiết bị chỉ có thể *kéo xuống 0* hoặc *thả ra*, mức logic trên dây là phép AND của tất cả thiết bị (**wired-AND**). Tính chất này là nền tảng cho ba cơ chế: clock stretching (slave giữ SCL thấp để đòi thêm thời gian), đồng bộ xung nhịp giữa nhiều master, và trọng tài không phá huỷ dữ liệu (non-destructive arbitration).

> ***Diễn giải:** Hãy hình dung hai dây I2C như hai sợi dây chuông mà ai cũng có thể giữ xuống, không ai đẩy lên được. Dây chỉ ở mức cao khi tất cả mọi người cùng buông tay. Nhờ vậy nhiều thiết bị cùng nối vào mà không bị chập mạch. Thiết bị chậm có thể giữ dây để bắt người khác chờ. Hai master cùng nói thì bên nào thấy dây khác với điều mình định gửi sẽ biết mình thua và tự rút lui.*

### 1.2 Mục tiêu nghiên cứu

- Hiểu cấu trúc phân cấp, luồng điều khiển và luồng dữ liệu của core đến mức từng thanh ghi và từng máy trạng thái (FSM).

- Suy ra các đặc tính định lượng: công thức tần số SCL, số pha trên mỗi bit, độ trễ ngắt.

- Đánh giá phần mở rộng DMA của QSOC về chức năng và tính đúng đắn giao thức.

- Kiểm tra wrapper tích hợp so với core và so với QNSC RTL Design Naming Rule V1.0.

- Đưa ra danh sách phát hiện và khuyến nghị trước khi tích hợp SoC.

> ***Diễn giải:** Nghiên cứu không dừng ở mức “biết core làm được gì”. Mục tiêu là hiểu đủ sâu để (a) tính được cấu hình đúng cho phần mềm, và (b) chỉ ra chỗ nào còn thiếu hoặc có thể sai trước khi đưa vào chip.*

### 1.3 Các lựa chọn và giả định nghiên cứu

| **Hạng mục** | **Lựa chọn** | **Lý do** |
|----|----|----|
| Core nguồn | pulp-platform/apb_i2c (lõi OpenCores I2C), giữ nguyên, không sửa | Đã được kiểm nghiệm lâu năm; dễ so sánh (diff) với upstream |
| Bản vá QSOC | Thêm REG_TXCMD/REG_RXCMD và 3 tín hiệu DMA | Cho phép kênh DMA ngoại vi truyền liên tục từng byte |
| Vị trí trên SoC | P_BUS, slot APB_S12, cửa sổ 4 KB (APB_ADDR_WIDTH = 12) | Theo address map QSOC |
| Chuẩn đặt tên | QNSC RTL Design Naming Rule V1.0, áp dụng tại biên wrapper | Third-party IP được chuẩn hoá ở wrapper, core giữ tên gốc |
| Phương pháp | Phân tích tĩnh RTL | Thấy toàn bộ logic, kể cả nhánh hiếm; chưa cần môi trường mô phỏng |

## 2. Phương pháp nghiên cứu

Nghiên cứu dùng phân tích tĩnh mã nguồn RTL, gồm bốn bước:

- **Phân rã phân cấp (top-down):** đi từ wrapper xuống apb_i2c, rồi i2c_master_byte_ctrl, rồi i2c_master_bit_ctrl; liệt kê đầy đủ cổng và kết nối instance ở mỗi cấp.

- **Trích xuất máy trạng thái:** dựng lại đồ thị chuyển trạng thái của hai FSM từ các khối case, và xác định giá trị SCL/SDA tại mỗi trạng thái.

- **Suy diễn định lượng:** tính chu kỳ SCL từ bộ đếm cnt, bộ lọc filter_cnt và số pha của mỗi bit.

- **Đối chiếu:** so với chuẩn I2C (START/STOP, ACK/NACK, arbitration), giao thức APB (hai pha SETUP/ACCESS) và QNSC Naming Rule V1.0.

**⚠** *Nghiên cứu chưa bao gồm mô phỏng hay tổng hợp (synthesis). Mọi kết luận định lượng về thời gian được ghi rõ là suy ra từ RTL và cần mô phỏng để xác nhận.*

> ***Diễn giải:** Có thể xem đây là bước “đọc kỹ bản thiết kế” chứ chưa phải “chạy thử”. Ưu điểm là thấy được toàn bộ logic. Hạn chế là các con số về tần số và độ trễ là ước lượng bằng lý luận, nên cần một testbench để kiểm chứng (mục 11).*

## 3. Kiến trúc tổng thể và phân cấp

### 3.1 Cây phân cấp

m_qnsc_wrap_apb_i2c (wapper_I2C/rtl/i2c_wrapper.sv)

└── u_i2c_0 : apb_i2c (apb_i2c.sv — APB, CSR, IRQ, DMA req)

└── byte_controller : i2c_master_byte_ctrl (FSM byte, thanh ghi dịch)

└── bit_controller : i2c_master_bit_ctrl (SCL gen, lọc, FSM bit, AL)

\`include i2c_master_defines.sv (mã lệnh I2C_CMD\_\*)

| **File** | **Số dòng** | **Vai trò** |
|----|----|----|
| apb_i2c.sv | 266 | Top core: APB, CSR, mux đọc, status/IRQ, DMA request |
| i2c_master_byte_ctrl.sv | 334 | FSM byte, thanh ghi dịch, bộ đếm bit |
| i2c_master_bit_ctrl.sv | 544 | Tạo SCL, lọc nhiễu, FSM bit, busy, arbitration |
| i2c_master_defines.sv | 61 | Mã lệnh I2C_CMD\_{NOP, START, STOP, WRITE, READ} |
| i2c_wrapper.sv | 69 | Wrapper QSOC m_qnsc_wrap_apb_i2c |

### 3.2 Phân lớp trách nhiệm

| **Lớp** | **Đơn vị thời gian** | **Trách nhiệm** |
|----|----|----|
| apb_i2c | Giao dịch APB | Giải mã địa chỉ, lưu CSR, chọn dữ liệu đọc, tạo IRQ/DMA request |
| byte_ctrl | Byte (8 bit + ACK) | Nạp/dịch dữ liệu, đếm bit, sắp chuỗi START → dữ liệu → ACK → STOP |
| bit_ctrl | Pha của một bit (¼ chu kỳ SCL) | Tạo xung SCL, đặt/đọc SDA, lọc nhiễu, phát hiện START/STOP, busy, arbitration |

Kiến trúc này là một hệ điều khiển phân cấp theo thang thời gian (hierarchical time-scale decomposition). Mỗi lớp chỉ giao tiếp với lớp kề nó qua một giao thức bắt tay lệnh/xác nhận đơn giản: cmd/cmd_ack giữa byte và bit, start/stop/read/write/cmd_ack giữa CSR và byte. Cách phân tách này giảm độ phức tạp cục bộ của từng FSM. Byte FSM chỉ có 6 trạng thái và không cần biết thời gian SCL. Bit FSM có 18 trạng thái và không cần biết byte có bao nhiêu bit.

> ***Diễn giải:** Giống một công ty ba tầng. Tầng trên (CSR) nhận “đơn hàng” từ CPU, ví dụ “gửi byte 0xA0 kèm START”. Tầng giữa (byte) chia đơn hàng thành 8 bit + 1 bit ACK. Tầng dưới (bit) thực sự bật/tắt SCL, SDA theo đúng nhịp. Mỗi tầng chỉ nói với tầng ngay dưới bằng hai câu “làm việc này” và “đã xong”, nên từng phần dễ hiểu và dễ kiểm tra.*

### 3.3 Sơ đồ khối

Hình 3.1 thể hiện wrapper cùng sơ đồ chân ở cả mặt wrapper lẫn mặt core; Hình 3.2 thể hiện cấu trúc chi tiết bên trong core. Bản gốc có thể chỉnh sửa nằm trong wapper_I2C/i2c_wrapper_block_diagram.drawio.

*[figure not reproduced]*

**Figure 3.1. Wrapper m_qnsc_wrap_apb_i2c — sơ đồ khối và sơ đồ chân wrapper ↔ core**

*[figure not reproduced]*

**Figure 3.2. Core IP apb_i2c — cấu trúc chi tiết (CSR, byte_controller, bit_controller)**

## 4. Giao diện APB và bản đồ thanh ghi

### 4.1 Giao thức truy cập

assign s_apb_addr = PADDR\[5:2\];

// ghi : PSEL && PENABLE && PWRITE (cạnh lên HCLK của pha ACCESS)

// đọc : PRDATA tổ hợp theo s_apb_addr

assign PREADY = 1'b1;

assign PSLVERR = 1'b0;

Core là APB slave không có trạng thái chờ (zero wait-state). Thanh ghi được ghi ở cạnh lên HCLK trong pha ACCESS (PSEL & PENABLE & PWRITE). Dữ liệu đọc PRDATA là tổ hợp thuần theo PADDR\[5:2\], nên đã ổn định từ pha SETUP. PREADY luôn bằng 1 và PSLVERR luôn bằng 0. Hệ quả: truy cập vào offset không tồn tại không báo lỗi (ghi bị bỏ qua, đọc trả về 0), và core không thể kéo dài giao dịch.

> ***Diễn giải:** Mỗi lần CPU đọc/ghi thanh ghi I2C chỉ mất đúng 2 chu kỳ bus, nhanh nhất mà APB cho phép. Đổi lại, nếu phần mềm ghi nhầm địa chỉ thì phần cứng im lặng, không báo lỗi. Phần mềm phải tự đảm bảo dùng đúng offset.*

### 4.2 Không gian địa chỉ và hiện tượng alias

Chỉ các bit PADDR\[5:2\] được giải mã. Hằng số REG\_\* rộng 3 bit, được so với s_apb_addr 4 bit (mở rộng bằng 0 ở bit cao). Vì vậy:

- Offset 0x00–0x1C (PADDR\[5\]=0) ánh xạ vào 8 thanh ghi.

- Offset 0x20–0x3C (PADDR\[5\]=1) không khớp nhánh nào: ghi bị bỏ qua, đọc trả về 0.

- Các bit PADDR\[11:6\] bị bỏ qua hoàn toàn, nên khối 64 byte trên lặp lại (alias) 64 lần trong cửa sổ 4 KB.

- PADDR\[1:0\] bị bỏ qua. Core giả định truy cập 32 bit căn lề và không dùng PSTRB (APB4).

> ***Diễn giải:** Core chỉ nhìn 4 bit địa chỉ, nên cùng một thanh ghi xuất hiện ở nhiều địa chỉ trong vùng 4 KB (ví dụ BASE+0x04 và BASE+0x44 đều là CTRL). Về chức năng thì không sao, nhưng memory map của SoC nên ghi rõ để người viết driver hay kiểm chứng không bất ngờ.*

### 4.3 Bản đồ thanh ghi

**Bảng 4.1. Bản đồ thanh ghi apb_i2c (offset tính từ BASEADDR)**

| **Offset** | **Tên** | **Thanh ghi RTL** | **Truy cập** | **Trường bit / Ý nghĩa** |
|----|----|----|----|----|
| 0x00 | CLK_PRESCALER | r_pre\[15:0\] | RW | Hệ số chia SCL (PRER) — xem mục 6.2 |
| 0x04 | CTRL | r_ctrl\[7:0\] | RW | \[7\] EN bật core · \[6\] IEN bật ngắt |
| 0x08 | RX | s_rx\[7:0\] | RO | Byte nhận được gần nhất |
| 0x0C | STATUS | s_status\[7:0\] | RO | \[7\] RxACK · \[6\] BUSY · \[5\] AL · \[1\] TIP · \[0\] IF |
| 0x10 | TX | r_tx\[7:0\] | RW | Byte cần gửi |
| 0x14 | CMD | r_cmd\[7:0\] | RW † | \[7\] STA · \[6\] STO · \[5\] RD · \[4\] WR · \[3\] ACK · \[0\] IACK |
| 0x18 | TXCMD | r_tx + r_cmd | WO | \[7:0\] dữ liệu · \[8\] STA · \[9\] STO; tự đặt WR=1 (QSOC) |
| 0x1C | RXCMD | s_rx / r_cmd | RO | Trả s_rx, đồng thời tự phát RD; STO = ACK = dma_last_i (QSOC) |

† CMD chỉ được ghi khi EN=1. Các bit \[7:4\] tự xoá khi lệnh xong (s_done) hoặc khi mất trọng tài (i2c_al). Các bit \[2:0\] tự xoá sau một chu kỳ.

So với core OpenCores gốc, bản đồ đã được sắp xếp lại. Các cặp TXR/RXR và CR/SR vốn dùng chung địa chỉ (phân biệt bằng chiều đọc/ghi) nay được tách thành các offset riêng: RX=0x08 và TX=0x10, STATUS=0x0C và CMD=0x14. Cách này đơn giản hoá bộ giải mã và cho phép đọc lại mọi thanh ghi ghi được, rất có lợi cho gỡ lỗi. Đổi lại, driver viết cho OpenCores gốc (ví dụ Linux i2c-ocores) không dùng lại được mà không sửa offset.

> ***Diễn giải:** Có 6 thanh ghi gốc và 2 thanh ghi mới do QSOC thêm cho DMA. Điều cần nhớ: không dùng driver OpenCores nguyên bản, vì offset đã khác. Mọi thanh ghi đọc lại được, nên khi debug có thể dump toàn bộ để xem trạng thái.*

### 4.4 Bộ chọn dữ liệu đọc (PRDATA mux)

case (s_apb_addr)

0x00: PRDATA = {16'h0, r_pre}; 0x04: PRDATA = {24'h0, r_ctrl};

0x08: PRDATA = {24'h0, s_rx}; 0x0C: PRDATA = {24'h0, s_status};

0x10: PRDATA = {24'h0, r_tx}; 0x14: PRDATA = {24'h0, r_cmd};

0x1C: PRDATA = {24'h0, s_rx}; default: PRDATA = 32'h0; // 0x18 đọc = 0

endcase

PRDATA là tổ hợp và không phụ thuộc PSEL, nên thay đổi theo PADDR ngay cả khi slave không được chọn. Điều này đúng chuẩn APB, vì bus master chỉ lấy mẫu PRDATA của slave đang được chọn. Tuy nhiên, nó làm tăng toggle trên bus đọc và kéo dài đường tổ hợp PADDR → PRDATA, cần tính đến trong phân tích timing.

> ***Diễn giải:** Đầu ra đọc chạy theo địa chỉ mọi lúc. Về chức năng thì đúng, chỉ tốn chút năng lượng và phải chú ý khi đóng timing. Đây không phải lỗi.*

## 5. Byte controller (i2c_master_byte_ctrl)

### 5.1 Cổng và tài nguyên dữ liệu

| **Nhóm** | **Cổng vào** | **Cổng ra** |
|----|----|----|
| Clock/reset/cấu hình | clk, nReset, ena, clk_cnt\[15:0\] | — |
| Lệnh / dữ liệu | start, stop, read, write, ack_in, din\[7:0\] | cmd_ack, ack_out, dout\[7:0\] |
| Trạng thái bus | — | i2c_busy, i2c_al |
| Pad | scl_i, sda_i | scl_o, scl_oen, sda_o, sda_oen |

- **Thanh ghi dịch** sr\[7:0\]**:** khi ld nạp din; khi shift dịch trái {sr\[6:0\], core_rxd}. core_txd = sr\[7\], tức truyền **MSB trước** đúng chuẩn I2C. Cùng một thanh ghi dùng cho cả gửi (dịch ra từ MSB) và nhận (dịch vào từ LSB).

- **Bộ đếm** dcnt\[2:0\]**:** khi ld nạp 7, mỗi lần shift giảm 1; cnt_done = ~\|dcnt.

> ***Diễn giải:** Chỉ một thanh ghi 8 bit vừa làm băng chuyền đẩy bit ra khi gửi, vừa gom bit vào khi nhận. Bộ đếm 3 bit đếm ngược 7→0 để biết khi nào đủ 8 bit. Thiết kế tiết kiệm diện tích.*

### 5.2 Máy trạng thái byte

Tín hiệu kích hoạt: go = (read \| write \| stop) & ~cmd_ack.

**Bảng 5.1. Chuyển trạng thái của byte FSM (c_state\[4:0\], one-hot)**

<table>
<colgroup>
<col style="width: 17%" />
<col style="width: 31%" />
<col style="width: 51%" />
</colgroup>
<thead>
<tr>
<th><strong>Trạng thái</strong></th>
<th><strong>Lệnh gửi xuống bit_ctrl</strong></th>
<th><strong>Điều kiện chuyển</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>IDLE</td>
<td>theo ưu tiên start &gt; read &gt; write &gt; stop</td>
<td>go → START / READ / WRITE / STOP; ld = 1</td>
</tr>
<tr>
<td>START</td>
<td>I2C_CMD_START</td>
<td>core_ack → READ (nếu read) hoặc WRITE</td>
</tr>
<tr>
<td>WRITE</td>
<td>I2C_CMD_WRITE ×8</td>
<td><p>core_ack &amp; ~cnt_done → dịch, ở lại</p>
<p>core_ack &amp; cnt_done → ACK (lệnh READ để đọc ACK của slave)</p></td>
</tr>
<tr>
<td>READ</td>
<td>I2C_CMD_READ ×8</td>
<td>core_ack → dịch; cnt_done → ACK (lệnh WRITE, core_txd = ack_in)</td>
</tr>
<tr>
<td>ACK</td>
<td>—</td>
<td>core_ack: ack_out ← core_rxd; stop → STOP, ngược lại → IDLE và cmd_ack = 1</td>
</tr>
<tr>
<td>STOP</td>
<td>I2C_CMD_STOP</td>
<td>core_ack → IDLE và cmd_ack = 1</td>
</tr>
<tr>
<td>(mọi trạng thái)</td>
<td>NOP</td>
<td>i2c_al → IDLE ngay lập tức</td>
</tr>
</tbody>
</table>

Có ba tính chất đáng chú ý:

- **START không phải lệnh độc lập.** Vì go không chứa start, ghi STA=1 một mình không khởi động gì. STA phải đi kèm WR (START + byte địa chỉ) hoặc RD. Repeated START được tạo bằng cách ghi STA\|WR giữa hai giao dịch mà không có STO.

- **Tính đối xứng ACK.** Khi gửi, pha ACK *đọc* bit thứ 9 do slave trả về (ack_out, tức SR.RxACK). Khi nhận, pha ACK *gửi* bit thứ 9 do master quyết định (ack_in: 0 = ACK, 1 = NACK).

- cmd_ack **chỉ phát một lần mỗi giao dịch byte**, ở cuối ACK hoặc STOP. Chuỗi START → 8 bit → ACK → STOP tạo đúng một xung s_done gửi lên lớp CSR.

> ***Diễn giải:** Mỗi lần CPU ra lệnh, byte controller làm trọn một gói gồm START (nếu có), 8 bit dữ liệu, 1 bit ACK và STOP (nếu có), rồi báo “xong” một lần. Điểm dễ nhầm với người mới: ghi riêng bit START sẽ không có gì xảy ra, START luôn phải đi kèm lệnh gửi (WR) hoặc nhận (RD). Bit ACK ở chiều gửi là “slave có nghe thấy không”, còn ở chiều nhận là “master có muốn nhận tiếp không”.*

## 6. Bit controller (i2c_master_bit_ctrl)

Đây là lớp phức tạp nhất và quyết định chất lượng tín hiệu điện trên bus.

### 6.1 Đường vào: đồng bộ và lọc nhiễu

scl_i ─► cSCL\[1:0\] (2-FF sync) ─► fSCL\[2:0\] (lấy mẫu mỗi filter_cnt) ─► sSCL (đa số 2/3) ─► dSCL (trễ 1 clk)

- cSCL/cSDA: bộ đồng bộ hai flip-flop, giảm xác suất metastability vì SCL/SDA là tín hiệu bất đồng bộ từ chân chip.

- filter_cnt\[13:0\] được nạp lại bằng clk_cnt \>\> 2, nên bộ lọc lấy mẫu với chu kỳ khoảng ¼ chu kỳ clk_en, tức khoảng 16 lần tần số SCL.

- sSCL = maj(fSCL\[2:0\]): bỏ phiếu đa số 3 mẫu, loại gai nhiễu ngắn hơn khoảng một chu kỳ lấy mẫu.

- dSCL/dSDA: bản trễ 1 chu kỳ, dùng để phát hiện cạnh.

> ***Diễn giải:** Tín hiệu từ ngoài chip vào có thể có nhiễu và không đồng bộ với xung nhịp bên trong. Core xử lý theo hai lớp: (1) qua 2 flip-flop cho ổn định, (2) lấy 3 mẫu cách đều rồi bỏ phiếu, 2/3 mẫu nói 1 thì là 1. Nhờ vậy gai nhiễu ngắn không bị hiểu nhầm thành xung nhịp. Fast-mode yêu cầu lọc gai dưới 50 ns; mức lọc ở đây tỷ lệ theo prescaler, nên cần kiểm tra con số cụ thể theo tần số HCLK.*

### 6.2 Bộ tạo xung nhịp và công thức tần số SCL

if (~\|cnt \|\| !ena \|\| scl_sync) begin cnt \<= clk_cnt; clk_en \<= 1'b1; end

else if (slave_wait) begin cnt \<= cnt; clk_en \<= 1'b0; end

else begin cnt \<= cnt - 1; clk_en \<= 1'b0; end

**Suy diễn.** Khi không có slave_wait, cnt giảm từ PRER về 0 rồi nạp lại, nên clk_en xuất hiện mỗi PRER + 1 chu kỳ HCLK. Mọi thao tác bit gồm 4 pha a → b → c → d, mỗi pha một chu kỳ clk_en. Vậy chu kỳ SCL danh định là:

*T_SCL,nom = 4 · (PRER + 1) · T_HCLK*

Ngoài ra, ở pha master thả SCL (pha b), slave_wait = scl_oen & ~dscl_oen & ~sSCL bật lên vì sSCL còn trễ qua đường đồng bộ và lọc. Bộ đếm bị giữ lại cho tới khi sSCL lên 1. Mỗi bit do đó dài thêm một lượng Δ_filter (2-FF + tối đa khoảng 2 chu kỳ lấy mẫu lọc + 1 FF), cộng thời gian lên t_rise của dây (do Rp và điện dung bus):

*T_SCL ≈ 4·(PRER+1)·T_HCLK + Δ_filter + t_rise*

*Δ_filter ≈ \[2·((PRER\>\>2)+1) + 3\]·T_HCLK*

Tài liệu OpenCores gốc khuyến nghị PRER = f_HCLK / (5·f_SCL) − 1, tức coi mỗi chu kỳ SCL khoảng 5 lần (PRER+1). Theo suy diễn trên, hệ số thực nằm trong khoảng 4 đến 5, tuỳ trễ lọc và rise time. Ví dụ với f_HCLK = 50 MHz, mục tiêu 100 kHz (Standard-mode):

**Bảng 6.1. Ước lượng tần số SCL theo hai cách chọn PRER (f_HCLK = 50 MHz)**

| **Cách chọn** | **PRER** | **T_SCL ước lượng** | **f_SCL ước lượng** |
|----|----|----|----|
| Công thức OpenCores (÷5) | 99 | ≈ 400 + 53 = 453 chu kỳ (+ t_rise) | ≈ 110 kHz — vượt 100 kHz |
| Công thức danh định (÷4) | 124 | ≈ 500 + 67 = 567 chu kỳ (+ t_rise) | ≈ 88 kHz — an toàn |

**⚠** *Không nên áp công thức ÷5 một cách máy móc cho Standard-mode. Cần chọn PRER sao cho f_SCL thực không vượt giới hạn chuẩn và xác nhận bằng mô phỏng hoặc đo thực tế.*

> ***Diễn giải:** PRER là núm vặn tốc độ. Mỗi bit I2C tốn 4 nhịp, mỗi nhịp dài PRER+1 xung HCLK, và core còn chờ thêm một chút mỗi bit để chắc chắn dây SCL đã thực sự lên cao. Vì vậy tốc độ thật luôn chậm hơn phép tính đơn giản. Bài học thực tế: nếu áp nguyên công thức trong tài liệu gốc, bus có thể chạy nhanh hơn 100 kHz một chút, vi phạm chuẩn với slave chậm. Các con số trong bảng là ước lượng suy ra từ RTL.*

### 6.3 Clock stretching và đồng bộ xung nhịp multi-master

- **Clock stretching:** slave_wait giữ cnt đứng yên khi master đã thả SCL nhưng SCL thực vẫn thấp (slave đang giữ). FSM đứng chờ đến khi slave nhả dây.

- **Đồng bộ multi-master:** scl_sync = dSCL & ~sSCL & scl_oen phát hiện SCL bị thiết bị khác kéo xuống trong khi master này đang thả dây. Khi đó cnt được nạp lại ngay, để pha thấp của master này bắt đầu cùng lúc với master kia. Đây là cơ chế tạo “SCL chung” bằng wired-AND theo chuẩn I2C.

> ***Diễn giải:** Slave chậm có thể giữ SCL thấp để xin thêm thời gian, và core sẽ kiên nhẫn chờ. Khi có hai master, nhịp của chúng tự khớp nhau: ai kéo xuống trước thì cả hai cùng tính lại từ đó. Hai tính năng này giúp core làm việc được với cảm biến/EEPROM chậm và trong hệ nhiều master.*

### 6.4 Phát hiện điều kiện bus (START/STOP/BUSY)

sta_condition \<= ~sSDA & dSDA & sSCL; // SDA cạnh xuống khi SCL=1 → START

sto_condition \<= sSDA & ~dSDA & sSCL; // SDA cạnh lên khi SCL=1 → STOP

busy \<= (sta_condition \| busy) & ~sto_condition;

busy (tức SR.BUSY) phản ánh trạng thái bus toàn cục: nó bật lên cả khi một master khác tạo START. Phần mềm nhờ đó biết bus đang bị chiếm trước khi phát START của mình.

> ***Diễn giải:** Theo chuẩn I2C, START và STOP là hai dấu hiệu đặc biệt: SDA thay đổi trong lúc SCL đang cao (bình thường SDA chỉ được đổi khi SCL thấp). Core luôn nghe bus để nhận ra hai dấu hiệu này, nên bit BUSY cho biết có ai đang dùng bus hay không, kể cả khi người đó không phải là mình.*

### 6.5 Phát hiện mất trọng tài (Arbitration Lost)

al \<= (sda_chk & ~sSDA & sda_oen) // thả SDA (muốn 1) nhưng đọc về 0

\| (\|c_state & sto_condition & ~cmd_stop); // gặp STOP ngoài ý muốn giữa giao dịch

Có hai nguyên nhân. (1) Trong pha ghi bit, sau khi SCL lên (sda_chk=1), master đang thả SDA nhưng đọc về 0, tức một thiết bị khác đang gửi bit 0 và master này thua trọng tài theo quy tắc wired-AND. (2) Có điều kiện STOP xuất hiện khi FSM không ở idle và lệnh hiện tại không phải STOP. Khi al=1, bit FSM lập tức về idle và thả cả SCL lẫn SDA; byte FSM về IDLE; lớp CSR xoá r_cmd\[7:4\], bật SR.AL và irq_flag.

> ***Diễn giải:** Hai master cùng nói một lúc: master gửi bit 1 (thả dây) nhưng thấy dây bị kéo về 0 thì biết có người khác đang gửi 0, tức là mình thua. Core lập tức im lặng, buông dây, báo lỗi AL và gây ngắt để phần mềm thử lại sau. Bên thắng không bị hỏng dữ liệu. Đó là ý nghĩa của “trọng tài không phá huỷ”.*

### 6.6 Máy trạng thái bit (18 trạng thái one-hot)

Mỗi pha dài một chu kỳ clk_en. Ký hiệu: oen = 1 là thả dây (mức 1 nhờ Rp), oen = 0 là kéo xuống 0.

**Bảng 6.2. Giá trị SCL/SDA theo từng pha của bit FSM**

| **Lệnh** | **Pha** | **SCL** | **SDA** | **Ghi chú** |
|----|----|----|----|----|
| START | a | giữ | 1 | Chuẩn bị SDA cao (hỗ trợ repeated START) |
|  | b | 1 | 1 |  |
|  | c | 1 | 0 (↓) | SDA xuống khi SCL = 1 → điều kiện START |
|  | d | 1 | 0 | Thời gian giữ t_HD;STA |
|  | e | 0 (↓) | 0 | cmd_ack = 1 |
| STOP | a | 0 | 0 |  |
|  | b | 1 | 0 |  |
|  | c | 1 | 0 | Thời gian thiết lập t_SU;STO |
|  | d | 1 | 1 (↑) | SDA lên khi SCL = 1 → điều kiện STOP; cmd_ack = 1 |
| WRITE | a | 0 | din | Đặt dữ liệu khi SCL thấp |
|  | b | 1 | din |  |
|  | c | 1 | din | sda_chk = 1: kiểm tra arbitration |
|  | d | 0 | din | cmd_ack = 1 |
| READ | a | 0 | thả |  |
|  | b | 1 | thả |  |
|  | c | 1 | thả | dout ← sSDA tại cạnh lên của sSCL |
|  | d | 0 | thả | cmd_ack = 1 |

Mã hoá one-hot 18 bit (idle = toàn 0) cho giải mã trạng thái nhanh và dễ tổng hợp, đổi lại tốn 18 flip-flop. scl_o và sda_o được gán hằng 1'b0, nên mọi thông tin mức logic nằm trong scl_oen/sda_oen. Đây là cách mô hình hoá open-drain chính xác: chân chip chỉ có hai trạng thái, kéo 0 hoặc trở kháng cao.

> ***Diễn giải:** Bảng trên là “vũ đạo” của hai dây cho từng loại việc. Quy tắc vàng của I2C thể hiện rõ: dữ liệu SDA chỉ đổi khi SCL thấp (pha a/d), còn SDA đổi khi SCL cao nghĩa là START/STOP (pha c của START, pha d của STOP). Core không bao giờ đẩy dây lên 1, chỉ buông tay để điện trở kéo lên, đúng bản chất open-drain.*

## 7. Khối trạng thái và ngắt

al \<= i2c_al \| (al & ~sta); // giữ tới khi phát START mới

rxack \<= s_irxack; // bit ACK nhận từ slave

tip \<= rd \| wr; // đang truyền

irq_flag \<= (s_done \| i2c_al \| irq_flag) & ~iack; // cờ ngắt dính (sticky)

interrupt_o \<= irq_flag & s_ien; // ra qua flip-flop

irq_flag là cờ dính (sticky). Nó bật khi hoàn tất một lệnh hoặc khi mất trọng tài, và chỉ được xoá khi phần mềm ghi CMD.IACK=1. interrupt_o là tín hiệu mức (level-sensitive), đi qua flip-flop nên không có glitch tổ hợp khi vào event manager của SoC. Độ trễ từ s_done tới interrupt_o là 2 chu kỳ HCLK. SR.AL giữ cho tới khi phát STA mới, giúp phần mềm chẩn đoán sau sự việc.

> ***Diễn giải:** Mỗi khi làm xong một lệnh (hoặc gặp tranh chấp bus), core “giơ tay” và giữ tay cho tới khi CPU trả lời “đã biết” bằng cách ghi bit IACK. Nếu IEN tắt, cờ vẫn có trong STATUS nhưng không gửi ngắt, và CPU có thể hỏi vòng (polling). Tín hiệu ngắt ra ngoài sạch vì đi qua flip-flop.*

## 8. Mở rộng DMA của QSOC

### 8.1 Động cơ

Với core gốc, mỗi byte cần ít nhất hai lần truy cập APB: ghi TX rồi ghi CMD (hoặc ghi CMD rồi đọc RX). Một kênh DMA ngoại vi kích hoạt (peripheral-triggered) chỉ làm tốt việc chuyển dữ liệu giữa **một địa chỉ cố định** và bộ nhớ, không thể chèn một lần ghi lệnh xen giữa. QSOC giải quyết bằng các thanh ghi kết hợp: **một lần truy cập vừa chuyển dữ liệu vừa phát lệnh**.

> ***Diễn giải:** DMA giống một băng chuyền chỉ biết lặp đi lặp lại “lấy một ô ở bộ nhớ, đặt vào một chỗ cố định”. Core gốc lại cần hai bước cho mỗi byte (“đặt dữ liệu” rồi “bấm nút gửi”). Hai thanh ghi mới gộp hai bước thành một để băng chuyền DMA dùng được.*

### 8.2 REG_TXCMD (0x18) — luồng gửi

r_tx \<= PWDATA\[7:0\];

if (s_core_en) // r_cmd = {sta, sto, rd, wr, ack, rsvd\[1:0\], iack}

r_cmd \<= {PWDATA\[8\], PWDATA\[9\], 1'b0, 1'b1, 1'b0, 2'b0, 1'b0};

Mỗi từ 32 bit trong bộ đệm nguồn DMA mang \[7:0\] dữ liệu, \[8\] STA và \[9\] STO. Phần mềm đánh dấu trước byte đầu (STA, thường là byte địa chỉ) và byte cuối (STO) trong bộ đệm; DMA chỉ việc chép tuần tự. Hệ quả: bộ đệm TX phải dùng phần tử 32 bit (hoặc ít nhất 16 bit), không thể là mảng byte liền nhau.

> ***Diễn giải:** Mỗi ô trong bộ nhớ nguồn không chỉ chứa byte dữ liệu mà còn có 2 bit cờ “byte này mở đầu giao dịch” và “byte này kết thúc giao dịch”. Phần mềm chuẩn bị sẵn danh sách, DMA đẩy đi từng ô, core tự biết lúc nào phát START/STOP.*

### 8.3 REG_RXCMD (0x1C) — luồng nhận

// Đọc RXCMD: PRDATA = s_rx (byte TRƯỚC ĐÓ), đồng thời phát lệnh RD cho byte kế

r_cmd \<= {1'b0, dma_last_i, 1'b1, 1'b0, dma_last_i, 2'b0, 1'b0};

// sta sto rd wr ack

- **Độ lệch một byte (pipeline 1 tầng).** Lần đọc thứ k trả về byte do lệnh RD thứ k−1 nhận được, đồng thời phát lệnh RD thứ k. Vì vậy lần đọc đầu tiên trả về giá trị cũ và cần một lần đọc mồi (priming), hoặc phần mềm phát lệnh RD đầu tiên qua CMD rồi mới cho DMA đọc N lần.

- **Kết thúc bằng NACK + STOP.** Khi dma_last_i=1 trong lần đọc phát lệnh cho byte cuối, ACK=1 (NACK) và STO=1: master báo slave “đây là byte cuối” rồi phát STOP, đúng chuẩn I2C cho chiều master nhận.

> ***Diễn giải:** Mỗi lần DMA đọc ô RXCMD, nó nhận byte cũ và cùng lúc bảo core đọc tiếp byte mới, giống như ở quầy: mỗi lần lấy gói hàng đã xong thì gọi luôn món tiếp theo. Vì thế lần đầu tay không (phải “gọi món mồi”), và ở lần gọi cuối, DMA bật dma_last_i để core nói với slave “đủ rồi” (NACK) và kết thúc (STOP).*

### 8.4 Tín hiệu yêu cầu DMA

assign dma_tx_req_o = s_core_en & ~tip; // sẵn sàng nhận lệnh TXCMD tiếp theo

// rx_rdy_q: set khi (s_done & rd), clear khi đọc RXCMD

assign dma_rx_req_o = rx_rdy_q;

- dma_tx_req_o là tín hiệu mức, bật khi core rảnh. Vì tip được cập nhật một chu kỳ sau lần ghi TXCMD, dma_tx_req_o còn ở mức 1 thêm khoảng 1 chu kỳ sau lần ghi. Nếu kênh DMA lấy mẫu yêu cầu theo mức ngay chu kỳ kế, nó có thể phát thêm một lần ghi trùng và ghi đè r_tx. Cần đối chiếu với đặc tả bắt tay của kênh DMA (11_DMA_idma/doc/qsoc_periph_dma.md).

- dma_rx_req_o là tín hiệu mức có trạng thái (qua rx_rdy_q), được xoá đúng bởi lần đọc tiêu thụ nó, nên chặt chẽ hơn.

> ***Diễn giải:** Core gọi DMA bằng hai dây: “tôi sẵn sàng nhận byte để gửi” và “tôi có byte nhận được, lấy đi”. Dây nhận được thiết kế cẩn thận. Dây gửi còn một khe hở rất ngắn (1 chu kỳ) vẫn báo “sẵn sàng” ngay sau khi vừa nhận việc. Đây là điểm cần kiểm tra khi ghép với bộ DMA thật, tuỳ DMA phản ứng nhanh đến đâu.*

## 9. Wrapper tích hợp m_qnsc_wrap_apb_i2c

### 9.1 Mục đích

Wrapper là lớp chuẩn hoá biên (normalized at wrapper boundary) theo QNSC Naming Rule. Core bên thứ ba được giữ nguyên để dễ diff với upstream; chỉ biên ngoài được đổi tên và thích nghi điện.

> ***Diễn giải:** Core mua/lấy từ bên ngoài không bị sửa bên trong. Mọi điều chỉnh cho hợp quy ước QSOC đều nằm ở lớp vỏ mỏng bên ngoài, nên khi upstream có bản sửa lỗi có thể lấy về dễ dàng.*

### 9.2 Ánh xạ chân wrapper ↔ core

**Bảng 9.1. Ánh xạ chân**

| **Wrapper port** | **Hướng** | **Core port** | **Thích nghi** |
|----|----|----|----|
| i_clk_sys / i_rst_n_sys | in | HCLK / HRESETn | Đổi tên (§3.1–3.2), reset active-low, async |
| i_bus_apb_paddr \[P_APB_ADDR_WIDTH-1:0\] | in | PADDR | Nối thẳng, P_APB_ADDR_WIDTH = 12 |
| i_bus_apb_pwdata \[31:0\] | in | PWDATA | Nối thẳng |
| i_bus_apb_pwrite / psel / penable | in | PWRITE / PSEL / PENABLE | Nối thẳng; PSEL giải mã ở interconnect |
| o_bus_apb_prdata \[31:0\] | out | PRDATA | Nối thẳng |
| o_bus_apb_pready / pslverr | out | PREADY / PSLVERR | Nối thẳng (hằng 1 / 0) |
| o_int_i2c_0 | out | interrupt_o | Đổi tên (§3.6) |
| io_pad_i2c_scl | inout | scl_pad_i / scl_pad_o / scl_padoen_o | Mô phỏng open-drain |
| io_pad_i2c_sda | inout | sda_pad_i / sda_pad_o / sda_padoen_o | Mô phỏng open-drain |
| — (không có) | — | dma_last_i | ⚠ Chưa nối — thả nổi (z) |
| — (không có) | — | dma_tx_req_o / dma_rx_req_o | ⚠ Chưa nối — bỏ hở |

*[figure not reproduced]*

**Figure 9.1. Sơ đồ chân (pin-out) của wrapper, core và hai controller con**

### 9.3 Mô hình open-drain

assign io_pad_i2c_scl = w_i2c_scl_padoen_o ? 1'bz : w_i2c_scl_pad_o; // pad_o ≡ 0

assign w_i2c_scl_pad_i = io_pad_i2c_scl;

Biểu thức tương đương một bộ đệm ba trạng thái có enable tích cực mức thấp. Vì pad_o ≡ 0, dây chỉ có hai trạng thái: 0 (kéo xuống) hoặc z (thả). Đường vào đọc lại từ chính net inout, nên master nghe được mức thật trên bus (kết quả wired-AND), đúng yêu cầu của clock stretching và arbitration.

**⚠** *Ở mức mô phỏng, cách này đúng và đủ. Ở mức tổng hợp ASIC, gán 1'bz bên trong khối logic lõi (không phải tại pad cell) thường không được chấp nhận. Cấu trúc tri-state phải nằm trong pad cell open-drain ở IO ring, và wrapper khi đó nên xuất bộ ba i/o/oe cho IO MUX. Cần xác nhận với nhóm IO/backend.*

> ***Diễn giải:** Wrapper biến 6 dây tách rời của core thành 2 chân hai chiều đúng kiểu I2C, và điều đó chạy đúng khi mô phỏng. Nhưng khi làm chip thật, việc “thả nổi dây” thường chỉ làm được ở ô pad ngoài rìa chip. Trước khi tape-out cần thống nhất với nhóm IO: đặt mạch open-drain ở wrapper hay ở pad.*

## 10. Trình tự lập trình phần mềm

### 10.1 Khởi tạo

I2C-\>CLK_PRESCALER = PRER; // chọn theo mục 6.2, có kiểm tra

I2C-\>CTRL = (1 \<\< 7) \| (1 \<\< 6); // EN = 1, IEN = 1

### 10.2 Ghi một byte vào thanh ghi reg của slave addr7

I2C-\>TX = (addr7 \<\< 1) \| 0; I2C-\>CMD = STA \| WR; wait_if(); check(!SR.RxACK);

I2C-\>TX = reg; I2C-\>CMD = WR; wait_if(); check(!SR.RxACK);

I2C-\>TX = data; I2C-\>CMD = WR \| STO; wait_if();

### 10.3 Đọc một byte (repeated START)

I2C-\>TX = (addr7 \<\< 1) \| 0; I2C-\>CMD = STA \| WR; wait_if();

I2C-\>TX = reg; I2C-\>CMD = WR; wait_if();

I2C-\>TX = (addr7 \<\< 1) \| 1; I2C-\>CMD = STA \| WR; wait_if(); // repeated START

I2C-\>CMD = RD \| ACK \| STO; wait_if(); data = I2C-\>RX; // ACK = 1 → NACK

Trong đó wait_if() chờ SR.IF (hoặc ngắt), sau đó ghi CMD = IACK, và kiểm tra SR.AL.

> ***Diễn giải:** Đây là “công thức nấu” cho người viết driver. Mỗi dòng là một byte trên bus, tương ứng một lần core báo “xong”. Lưu ý hai điểm dễ nhầm đã phân tích: START phải đi kèm WR/RD (mục 5.2), và byte cuối khi đọc phải đặt ACK = 1 (NACK) kèm STO.*

## 11. Đánh giá, phát hiện và rủi ro

**Bảng 11.1. Danh sách phát hiện**

| **\#** | **Mức độ** | **Phát hiện** | **Khuyến nghị** |
|----|----|----|----|
| F1 | Cao | Wrapper không nối dma_last_i: ngõ vào thả nổi (z), nên khi đọc RXCMD, r_cmd\[6\] (STO) và r_cmd\[3\] (ACK) mang giá trị X | Buộc 1'b0 hoặc đưa ra port wrapper theo Naming Rule |
| F2 | Cao | dma_tx_req_o / dma_rx_req_o không được đưa ra ngoài wrapper, nên tính năng DMA không dùng được ở SoC | Thêm port o\_\* và nối vào kênh DMA ngoại vi |
| F3 | Trung bình | Công thức prescaler ÷5 của OpenCores có thể cho f_SCL vượt 100 kHz (mục 6.2) | Chọn PRER theo mô phỏng; ghi rõ trong tài liệu driver |
| F4 | Trung bình | dma_tx_req_o còn ở mức 1 thêm khoảng 1 chu kỳ sau ghi TXCMD (do tip trễ) — mục 8.4 | Đối chiếu đặc tả bắt tay DMA; cân nhắc che (mask) bằng wr tổ hợp |
| F5 | Trung bình | 1'bz trong wrapper không tổng hợp được thành logic lõi ASIC (mục 9.3) | Chuyển tri-state vào pad cell; wrapper xuất bộ ba i/o/oe |
| F6 | Thấp | Luồng RXCMD lệch 1 byte, lần đọc đầu trả rác (mục 8.3) | Ghi rõ quy trình mồi trong driver DMA |
| F7 | Thấp | Alias địa chỉ mỗi 64 B; truy cập sai offset không báo PSLVERR (mục 4.1–4.2) | Ghi chú trong memory map SoC |
| F8 | Thấp | Có \#1 trong byte_ctrl và \`timescale trong file include | Vô hại khi tổng hợp; lưu ý khi trộn timescale lúc mô phỏng |
| F9 | Thông tin | Bản đồ thanh ghi khác OpenCores gốc (mục 4.3) | Không dùng lại driver i2c-ocores mà không sửa |

> ***Diễn giải:** Có hai việc bắt buộc sửa trước khi tích hợp (F1, F2). Cả hai đều là thiếu dây nối trong wrapper, sửa rất nhanh, nhưng nếu bỏ qua thì tính năng DMA vô dụng và mô phỏng xuất hiện giá trị X. Ba việc nên kiểm tra kỹ (F3–F5) liên quan tới tốc độ bus, bắt tay DMA và cách làm pad khi ra chip thật. Các mục còn lại là ghi chú cho tài liệu và driver.*

## 12. Kết luận và hạng mục kỹ thuật còn mở

### 12.1 Kết luận

- Core apb_i2c là một I2C master hoàn chỉnh, kiểm nghiệm lâu năm (dựa trên lõi OpenCores), có kiến trúc ba lớp phân tách rõ theo thang thời gian. Core hỗ trợ đủ START / repeated START / STOP, ACK/NACK, clock stretching, đồng bộ multi-master và phát hiện mất trọng tài.

- Giao diện APB đơn giản, không có trạng thái chờ, khớp trực tiếp với P_BUS của QSOC.

- Phần mở rộng DMA (TXCMD/RXCMD + 3 tín hiệu bắt tay) có ý tưởng đúng: gộp dữ liệu và lệnh vào một truy cập ở địa chỉ cố định. Tuy vậy phần này cần hoàn thiện ở wrapper (F1, F2) và xác nhận thời gian bắt tay (F4).

- Wrapper tuân thủ QNSC Naming Rule V1.0 cho các cổng hiện có và mô hình open-drain đúng về chức năng. Cần làm rõ chiến lược pad cho tổng hợp (F5).

> ***Diễn giải:** Tóm lại: lõi tốt và tin cậy được; vỏ bọc gần xong nhưng còn thiếu mấy sợi dây cho DMA. Khi bổ sung các dây đó và chạy một testbench cơ bản, IP sẵn sàng đưa vào QSOC.*

### 12.2 Hạng mục kỹ thuật còn mở

- **Sửa wrapper:** thêm 3 cổng DMA theo Naming Rule và cập nhật sơ đồ draw.io.

- **Testbench smoke-test:** mô hình slave I2C (ví dụ EEPROM 24Cxx); kiểm tra ghi/đọc một byte, repeated START, NACK, clock stretching; đo f_SCL thực theo PRER.

- **Testbench DMA:** mô phỏng luồng TXCMD/RXCMD với mô hình kênh DMA, kiểm tra F4 và F6.

- **Kiểm tra hình thức (formal):** tính chất giao thức APB (PREADY/PRDATA) và tính one-hot của hai FSM.

- **Lint/CDC:** chạy Verilator/SpyGlass để bắt ngõ vào thả nổi và z nội bộ; xác nhận đường đồng bộ cSCL/cSDA được công cụ CDC nhận diện.

- **Pad strategy:** thống nhất với nhóm IO/backend về vị trí mạch open-drain (wrapper hay pad cell) và giao diện IO MUX.

> ***Diễn giải:** Bước tiếp theo nên là sửa dây trước, rồi viết testbench để biến các ước lượng trên giấy trong báo cáo này thành số đo thật.*

## 13. Phụ lục

### 13.1 Mã lệnh nội bộ byte → bit

| **Macro**     | **Mã**  | **Ý nghĩa**      |
|---------------|---------|------------------|
| I2C_CMD_NOP   | 4'b0000 | Không làm gì     |
| I2C_CMD_START | 4'b0001 | Phát START       |
| I2C_CMD_STOP  | 4'b0010 | Phát STOP        |
| I2C_CMD_WRITE | 4'b0100 | Ghi 1 bit (din)  |
| I2C_CMD_READ  | 4'b1000 | Đọc 1 bit (dout) |

### 13.2 Thuật ngữ

| **Thuật ngữ** | **Giải thích** |
|----|----|
| Open-drain | Ngõ ra chỉ kéo xuống 0 hoặc thả nổi; mức 1 do điện trở kéo lên tạo ra |
| Wired-AND | Mức trên dây = AND của mọi thiết bị, vì bất kỳ ai kéo 0 thì dây là 0 |
| Clock stretching | Slave giữ SCL thấp để làm chậm master |
| Arbitration lost (AL) | Master phát hiện mình thua khi tranh bus với master khác |
| Repeated START | START phát khi chưa có STOP, để đổi chiều giao dịch mà không nhả bus |
| One-hot | Mã hoá FSM mỗi trạng thái một flip-flop |
| Zero wait-state | Slave APB trả lời ngay, không kéo dài giao dịch |
| Sticky flag | Cờ giữ giá trị cho tới khi phần mềm xoá |

### 13.3 Tài liệu và file liên quan

- qsoc_dma_changes/present.md — bản trình bày Markdown cùng nội dung.

- wapper_I2C/i2c_wrapper_block_diagram.drawio — sơ đồ khối và pin-out (4 trang); gen_block_diagram.py để sinh lại.

- wapper_I2C/README.md, wapper_I2C/rtl/present.md — ghi chú đổi tên theo QNSC Naming Rule.

- QNSC RTL Design Naming Rule V1.0; UM10204 I2C-bus specification (NXP); AMBA APB Protocol Specification (Arm).
