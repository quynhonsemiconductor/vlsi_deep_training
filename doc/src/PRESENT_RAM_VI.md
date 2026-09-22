# Thuyết trình RAM — bản đọc

**Người viết:** Nghĩa VT · **Ngày:** 18/09/2026

## Dùng file này thế nào

**Phần I là bài nói.** Đọc thẳng một mạch, khoảng tám phút.

**Phần II không đọc lên.** Cùng thiết kế đó nhưng đầy đủ chiều sâu: vì sao quyết
định như vậy, làm sai thì hỏng ra sao, từ điển thuật ngữ, ngân hàng câu hỏi. Đọc ở
nhà để lúc bị cắt ngang thì câu trả lời đã sẵn trong đầu.

Thuật ngữ kỹ thuật, tên tín hiệu, tên thanh ghi giữ nguyên tiếng Anh.

## Slide

Cả hai hình đều **lấy nguyên từ tài liệu RAM**, không có hình riêng cho slide — nên
những gì thầy thấy trên màn hình khớp đúng những gì có trong spec.

| Hình | File | Là hình nào trong tài liệu | Lúc nào |
|---|---|---|---|
| **A** | `img/fig_qsoc_mem.png` | **Figure 1** — Where the RAM sits in QSOC | Phần 1 và 2 |
| **B** | `img/fig_ram_simple.png` | **Figure 2** — The AXI4 SRAM controller and its macro | Từ phần 4 tới hết |

---

# PHẦN I — BÀI NÓI

## 1. Mở đầu

Em nhận khối **RAM** của QSOC. Nghe là khối dễ nhất trong ba khối em nhận — bộ nhớ
thì chỉ có đọc và ghi. Nhưng nó là khối mà **cả con chip không boot được** nếu sai,
và là khối em tìm ra một lỗi trong IP mà 46 test của chính IP đó không bắt được.

## 2. Khối này để làm gì, nói trong một câu

Nó là một **AXI4 SRAM controller** cộng một **memory macro**: nhận transaction AXI4
trên `S_BUS`, dịch thành tín hiệu đọc ghi đơn giản của SRAM, và trả dữ liệu về.

Điểm quan trọng: **controller là IP, macro là thứ phụ thuộc công nghệ.** Controller
em lấy từ `nguyenquanicd/AXI4-SRAM-CONTROLLER`; macro thì trên FPGA là block RAM,
trên silicon là macro của PDK.

## 3. Câu hỏi em phải trả lời đầu tiên

**QSOC không có flash.** Đó là tiền đề của mọi thứ trong khối này.

Không flash nghĩa là chương trình **không** sẵn ở đâu cả khi chip ra khỏi reset.
Nó phải được **nạp vào RAM sau mỗi lần reset**, rồi **chạy từ RAM**. Nên RAM ở
QSOC không phải chỗ chứa biến — nó là chỗ **chứa chính chương trình**.

Từ đó ra ba câu hỏi em phải quyết:

1. Bao nhiêu là đủ, và chia thế nào?
2. Chương trình vào đó bằng đường nào?
3. Ai giữ nội dung lúc chip vừa bật, khi RAM còn là rác?

## 4. Bên trong khối có gì

Controller là **năm module**, và cả năm đều là IP — em không viết lại:

- **`m_vlsi_axi4_sram`** — top level, nối mọi thứ bên dưới;
- **`m_vlsi_axfsm`** — FSM địa chỉ AXI, **hai instance**: một cho `AW`, một cho `AR`.
  Nó lo bắt tay địa chỉ và **sinh địa chỉ từng beat** của burst;
- **`m_vlsi_fifo`** — FIFO đồng bộ có tham số, **năm instance**. Full và empty phát
  hiện bằng một bit MSB phụ của con trỏ;
- **`m_vlsi_arbiter`** — arbiter **round-robin** giữa yêu cầu đọc và ghi, vì macro
  chỉ có **một** cổng;
- **`m_vlsi_sram_misc`** — phần glue điều khiển và datapath: logic pop FIFO, mux địa
  chỉ và dữ liệu xuống SRAM, và sinh kênh `R` với `B`.

Năm FIFO đó dùng **chung một tham số** `PARA_FIFO_DEPTH`, nên không đặt sâu khác nhau
cho đường đọc và đường ghi được nếu không sửa top level.

**`ISRAM` và `DSRAM` là cùng một controller, instantiate hai lần.** Khác nhau **đúng
một tham số**: `PARA_SRAM_DEPTH` trên macro. Đổi dung lượng RAM là **sửa một tham
số, không sửa RTL**.

## 5. Bản đồ bộ nhớ em đề nghị

| Vùng | Dải | Cỡ | Cổng |
|---|---|---|---|
| `ROM` | `0x0000_0000` – `0x0000_07FF` | 2 KiB | `AXI_M0` |
| `ISRAM` debug window | `0x2000_0000` – `0x2000_0FFF` | 4 KiB | `AXI_M1` |
| `ISRAM` chương trình | `0x2000_1000` – `0x2000_FFFF` | **60 KiB** | `AXI_M1` |
| `DSRAM` | `0x3000_0000` – `0x3000_7FFF` | 32 KiB | `AXI_M2` |

**Hai dòng dễ đọc sai, nên em xin nói rõ.**

`ISRAM` là **64 KiB**, nhưng 4 KiB đầu là **debug window** — chỗ core nhảy tới khi
bị halt. Nên chỗ chương trình dùng được là **60 KiB, không phải 64**. Linker script
phải bắt đầu ảnh chính ở `0x2000_1000`.

**Tách `ISRAM` khỏi `DSRAM` là có chủ ý**: stack tràn thì không đè được lên chương
trình đang chạy, vì chúng ở hai macro trên hai cổng bus khác nhau.

## 6. Chương trình vào RAM bằng đường nào

**Đường chính là một serial bootloader nằm trong ROM.** Nó mở `UART0`, nhận một
frame `header` + `payload` + `CRC32`, ghi payload vào `ISRAM`, kiểm CRC rồi nhảy
vào. Ở 115200 baud, 22 KiB mất 2 giây và một ảnh đầy 60 KiB mất 5,4 giây. ROM chỉ
**2 KiB** — sau 128 B bảng vector còn **1920 B** dùng được, nên bootloader phải
**≤ 1 KiB** và bắt buộc dùng **CRC32 bitwise**; biến thể tra bảng (~2,1 KiB) **không
vừa**.

**Đường thứ hai là JTAG**, qua khối `SYSDBG` của em, dùng khi chính nội dung ROM
đáng nghi.

`ISRAM` cần 60 KiB trống là vì **bootloader đặt chương trình vào đó** (không phải để
chứa ảnh nạp qua JTAG).

## 7. ROM: bố cục bị chính reset vector của Ibex quy định

| Offset ROM | Nội dung |
|---|---|
| `0x000` – `0x07F` | Bảng vector `mtvec` — **32 cause × 4 byte = 128 byte** |
| `0x080` | **Điểm vào reset.** Lệnh đầu tiên CPU chạy trong đời |
| `0x080` – `0x7FF` | Toàn bộ boot code — **1920 byte** dùng được (ROM chỉ 2 KiB) |

Em không chọn `0x080` — **Ibex chọn**. Reset vector của nó là `boot_addr_i + 0x80`,
và bảng trap ở `boot_addr_i + 0x00`. Bảng phải đủ 32 entry chứ không phải 31, vì
**NMI là cause 31** nên nó là entry **cuối**, ở `mtvec + 0x7C`.

## 8. Ba thứ khối này chưa có, và một thứ em phải thêm

Nói ra chứ không che, vì cả bốn đều ảnh hưởng người khác:

- **Không có đường byte enable.** Controller không mang `WSTRB` xuống macro. Đây là
  thứ **em phải thêm**: `i_wstrb` vào port list, qua `WFIFO`, ra `o_sram_be`. Không
  có nó thì mọi lệnh ghi một byte sẽ ghi cả word.
- **`AxSIZE` không phải là một port.** Kích thước transfer **cố định bằng data
  width**, 32 bit. Một request hẹp hơn bị **bỏ qua**, không bị từ chối.
- **`BRESP` và `RRESP` luôn là `OKAY`.** RAM không bao giờ báo lỗi. Địa chỉ ngoài
  bản đồ phải do **bus decoder** trả `DECERR`, không phải RAM.
- **`WRAP` burst không wrap** — phần dưới.

## 9. Một phát hiện: `WRAP` không wrap

Đây là phần em muốn kể nhất.

`WRAP` là loại burst mà địa chỉ **quay vòng** trong một khối căn lề — CPU có cache
dùng nó để nạp một cache line bắt đầu từ giữa. Controller này **khai báo có hỗ trợ
`WRAP`**, nhưng khi em đọc bộ sinh địa chỉ thì nó **cộng tiếp như `INCR`**, không
quay vòng.

**Và 46 test của IP pass hết** — vì không test nào phát `WRAP`.

Đây là loại lỗi tệ nhất: một tính năng **khai là có**, **không báo lỗi**, và **chỉ
sai kết quả**. Không ai phát hiện tới lúc có một master thật dùng nó.

Hệ quả cho cả hệ thống, và là thứ em phải xin cả nhóm đồng ý: **mọi master trên
`S_BUS` chỉ được dùng `INCR` và `FIXED`.** Ibex không phát `WRAP`, DMA cấu hình được,
nên ràng buộc này chấp nhận được — nhưng nó phải được ghi ra, không phải để ngầm.

## 10. Clock và reset

`ROM` là domain **`D12`**, soft-reset bit **11**. `ISRAM` và `DSRAM` **dùng chung**
domain **`D13`** và bit **12**.

**Dùng chung có một cái bẫy, và em ghi nó vào tài liệu.** Soft-reset `D13` reset
**cả hai** RAM — mà `ISRAM` chính là nơi chứa **đoạn code vừa ghi lệnh reset đó**.
Nên lệnh này chỉ an toàn khi chạy **từ ROM**.

Em vẫn giữ chung. Tách ra thì thêm một gate, một bit, một thứ phải verify, mà lợi
ích chỉ có nghĩa khi có luồng recovery từng phần — bản này chưa có. Và đường lui còn
mở: `SOFT_RST_CTRL` còn chừa bit `[15:14]`.

## 11. Những gì em cần từ người khác

| Cần gì | Từ ai |
|---|---|
| Cho em thêm đường `WSTRB` | chủ IP / thầy |
| Master chỉ dùng `INCR` và `FIXED` | bus owner, CPU owner, DMA owner |
| `DECERR` cho địa chỉ ngoài bản đồ | bus owner |
| Macro SRAM **có byte write enable** | chủ công nghệ / FPGA |
| Chân macro không dùng nối theo databook | chủ physical design |
| Linker script bắt đầu ở `0x2000_1000` | người viết firmware |

## 12. Kết

Khối này trông đơn giản và phần lớn là IP. Đóng góp của em không phải viết lại nó,
mà là **đọc nó đủ kỹ để biết chỗ nào nó không làm như nó khai** — và biến ba chỗ đó
thành ràng buộc rõ ràng cho cả nhóm thay vì thành lỗi lúc tích hợp.

---

# PHẦN II — KHÔNG ĐỌC LÊN

## Vì sao từng quyết định lại như vậy

### Vì sao 64 KiB `ISRAM` và 32 KiB `DSRAM`

Bốn lập luận, và em có số cho từng cái:

**1. Bootloader đặt chương trình vào đó.** Không flash, nên toàn bộ ảnh phải vừa
trong `ISRAM`. 4 KiB đầu là debug window, nên app dùng được 60 KiB.

**2. Danh sách peripheral đã chốt, nên cost được firmware.** Driver cho UART, SPI,
I2C, GPIO, timer, PWM, DMA cộng một vòng lặp chính và vài KiB string với lookup
table — 60 KiB là đủ thoải mái, 28 KiB thì bắt đầu phải cắt tính năng.

**3. Block RAM không phải chỗ thắt trên board sẽ dùng.** Với M9K 9 Kbit: ROM 2 KiB
là 2 block, `ISRAM` 64 KiB là 64, `DSRAM` 32 KiB là 32 — tổng **98**, khoảng **54 %**
của một MAX 10. Trên Artix-7 35T thì hai RAM là 32 % và 46 % của 1 800 Kbit. Vừa.

**4. Chi phí sai là bất đối xứng, và đó là cái chốt.** Chọn 64 KiB mà thừa thì 32
block M9K ngồi không — 17 % thiết bị. Chọn 32 KiB mà thiếu thì phải **cắt tính năng
firmware**, hoặc **đổi RTL và chạy lại synthesis**. Một bên tốn tài nguyên, bên kia
tốn thời gian và rủi ro. Nên chọn rộng.

### Vì sao tách `ISRAM` và `DSRAM` thay vì một RAM

Instructor chỉ đạo tách. Nhưng nó cũng đúng về kỹ thuật: hai macro trên hai cổng bus
khác nhau nghĩa là **stack tràn không đè được lên code đang chạy**. Với một chip
không có MPU thì đó là cơ chế bảo vệ duy nhất có được mà không tốn gì.

Cái mất: hai cổng bus thay vì một, và không chia sẻ được dung lượng — `DSRAM` còn
trống thì `ISRAM` cũng không dùng được.

### Vì sao debug window là 4 KiB đầu của `ISRAM`, không phải một khối riêng

Ba phương án em cân:

| Phương án | Tốn gì |
|---|---|
| Một RAM nhỏ riêng cho debug | Thêm một slave, một decode window, một macro |
| Một debug ROM trong khối debug | Thêm slave port **trên khối debug** — chính thứ thiết kế đó tránh |
| **4 KiB đầu của `ISRAM`** | **Không gì cả — chỉ là một quy ước địa chỉ** |

Thầy chọn phương án ba. Phản đối duy nhất với nó là firmware có thể ghi đè vùng đó,
và câu trả lời là: đúng, nhưng linker script giải quyết, và đây là một chip training
chứ không phải chip có secure boot.

### Vì sao địa chỉ ở macro là byte address, và vì sao đó là bẫy

`o_sram_addr` mà controller phát ra là **byte** address. Một macro thật nhận **word**
address. Nối thẳng là **lệch hệ số 4** — địa chỉ 4 rơi vào word 4 thay vì word 1.

Trong mô phỏng với model hành vi thì có thể vẫn "chạy", vì model chỉ index một mảng.
Trên macro thật thì sai. Đây là loại lỗi phải bắt bằng **đọc**, không bắt được bằng
chạy test.

### Vì sao `BRESP`/`RRESP` tie `OKAY` là chấp nhận được **hiện tại**

Vì trong phạm vi hiện tại, RAM **không có gì để báo lỗi**: không có ECC, không có
parity, không có bảo vệ truy cập. Một RAM không thể phát hiện lỗi thì báo `OKAY` là
trung thực.

Nó **thành sai** nếu sau này thêm integrity. Lúc đó `RRESP` phải thành tín hiệu thật.
Nên tài liệu ghi cái này là **tie-off nhất quán với phạm vi hiện tại**, không phải
một thiết kế đúng vĩnh viễn.

## Năm module bên trong, chi tiết

| Module | Bên trong có gì | Chỗ dễ sai |
|---|---|---|
| `m_vlsi_axi4_sram` | Top level, instantiate và nối mọi thứ | Là chỗ duy nhất sửa được nếu muốn FIFO đọc và ghi sâu khác nhau |
| `m_vlsi_axfsm` ×2 | FSM bắt tay địa chỉ, và **sinh địa chỉ từng beat** theo `AxBURST` | **`WRAP` không wrap** — lỗi đã nói. Nằm đúng ở module này |
| `m_vlsi_fifo` ×5 | FIFO đồng bộ, full/empty bằng MSB phụ của con trỏ | `WSTRB` phải đi **cùng** data trong `WFIFO`, vì burst có thể khác strobe từng beat |
| `m_vlsi_arbiter` | **Round-robin** giữa đọc và ghi, vì macro một cổng | Round-robin nên **không** starve; nếu đổi sang ưu tiên cố định thì mới có |
| `m_vlsi_sram_misc` | Pop FIFO, mux địa chỉ và data xuống SRAM, sinh `R` và `B` | Byte address so với word address; `RLAST` lệch một beat là master treo |

## Verification

**Có sẵn cùng IP: 46 directed test**, chạy bằng Synopsys AXI VIP, phủ burst mọi
loại, mọi độ dài, cả outstanding.

**Em phải thêm:**

| Thêm gì | Vì sao |
|---|---|
| Test `WRAP` thật, so với model tham chiếu | 46 test kia không có, và đó là lý do lỗi sống sót |
| Test `WSTRB` từng beat khác nhau trong một burst | Đường em thêm vào, nên chưa ai test |
| Test ghi byte và halfword | Cùng lý do |
| Test địa chỉ vượt độ sâu macro | Hiện tại nó **alias** chứ không báo lỗi |

**Nói chủ động:** một regression tự kiểm chỉ đúng bằng model tham chiếu của nó. Với
`WRAP`, model phải viết từ **spec AXI**, không phải từ hành vi của RTL — nếu viết
theo RTL thì test sẽ xác nhận chính cái lỗi.

## Từ điển thuật ngữ

### Phía bus

| Thuật ngữ | Thực chất là gì |
|---|---|
| **AXI4** | Protocol bus tốc độ cao của QSOC. Nhiều kênh độc lập, có burst |
| **burst** | Một lệnh chuyển nhiều word liên tiếp |
| **`INCR`** | Burst địa chỉ tăng dần. Loại thường dùng nhất |
| **`FIXED`** | Burst mọi beat vào **cùng** một địa chỉ. Dùng cho FIFO |
| **`WRAP`** | Burst quay vòng trong khối căn lề. **Cái mà IP này khai có mà không làm** |
| **`WSTRB`** | Byte enable khi ghi: một bit cho mỗi byte, chọn byte nào được ghi |
| **`AxSIZE`** | Số byte mỗi beat. **Không phải port ở IP này** |
| **`BRESP` / `RRESP`** | Mã trả về của ghi / đọc. `OKAY`, `SLVERR`, `DECERR` |
| **`DECERR`** | Lỗi decode — không có slave nào ở địa chỉ đó |
| **outstanding** | Số transaction đã phát mà chưa có đáp |

### Phía bộ nhớ

| Thuật ngữ | Thực chất là gì |
|---|---|
| **SRAM macro** | Khối bộ nhớ vật lý. Trên FPGA là block RAM, trên silicon là khối của PDK |
| **single-port** | Một cổng, nên đọc và ghi phải **xếp hàng** — vì thế cần arbiter |
| **byte write enable** | Chân của macro cho ghi từng byte. **Bắt buộc** với đường `WSTRB` |
| **`PARA_SRAM_DEPTH`** | Số word của macro. Thứ **duy nhất** khác nhau giữa `ISRAM` và `DSRAM` |
| **margin / retention / test** | Chân không thuộc chức năng của macro thật. Model mô phỏng **không có**, nên không test nào fail vì chúng |

### Phía boot

| Thuật ngữ | Thực chất là gì |
|---|---|
| **bootloader** | Chương trình nhỏ trong ROM, nhận chương trình chính rồi nhảy vào |
| **`CRC32`** | Mã kiểm lỗi 32 bit. Làm theo bit thì nhỏ và chậm, tra bảng thì nhanh và tốn ~1 KiB |
| **reset vector** | Địa chỉ lệnh đầu tiên. Ibex: `boot_addr_i + 0x80` |
| **`mtvec`** | Gốc bảng trap. Ibex: `boot_addr_i + 0x00` |
| **linker script** | File nói mỗi đoạn code và data nằm ở địa chỉ nào |

## Ngân hàng câu hỏi

**Sao không tự viết controller?**
Vì đề bài là dựng một MCU chạy được, và một AXI4 SRAM controller là thứ đã có bản
tốt. Giá trị em thêm vào không phải gõ lại năm module đó, mà là **đọc chúng đủ kỹ để
tìm ra `WRAP` không wrap** — thứ mà nếu tự viết em cũng chưa chắc làm đúng.

**Sao biết `WRAP` sai? Test không bắt được mà.**
Vì em đọc bộ sinh địa chỉ chứ không chỉ chạy test. Nó cộng tiếp như `INCR`, không có
phép quay vòng nào. Và 46 test pass là **bằng chứng** cho chuyện đó — không test nào
phát `WRAP`, nên không test nào fail.

**Ràng buộc `INCR` và `FIXED` có gây khó cho ai không?**
Ibex không phát `WRAP`. DMA cấu hình được. Nên hiện tại không. Nhưng nó là ràng buộc
**phải ghi ra**, vì nếu sau này có master phát `WRAP` thì lỗi sẽ không báo gì cả, chỉ
trả sai dữ liệu.

**Sao `ISRAM` 64 KiB mà lại bảo 60?**
4 KiB đầu là debug window, chỗ core nhảy tới khi halt. App dùng 60 KiB từ
`0x2000_1000`.

**Nếu firmware ghi vào 4 KiB đó thì sao?**
Thì phá luôn đường debug — và tệ hơn là **chỉ phát hiện ra ở lần halt kế tiếp**. Nên
`QSOC_HAS` cho CPU bật **PMP** với một vùng phủ đúng 4 KiB đó, và granularity 0 để
biên vùng trùng khít `0x2000_0FFF`. Linker script vẫn phải tuân, nhưng giờ **có phần
cứng chặn** chứ không chỉ là quy ước. Đánh đổi này có chủ ý: nhờ nó mà khối debug
không cần một RAM riêng hay một slave port.

**2,0 giây và 5,4 giây tính ra sao?**
115200 baud, 8N1 là 10 bit mỗi byte. Nhưng con số dùng baud **thực**: divisor 11 ở
20 MHz cho 113 636 baud, thấp 1,4 %. 60 KiB là 61 440 byte × 10 bit chia 113 636 ra
**5,4 giây**. Nếu tính theo 115200 danh định thì ra 5,3 — nên tài liệu em ghi rõ chỗ
này, vì ai tự tính cũng sẽ nghĩ con số sai.

**Soft-reset `D13` trong lúc chạy từ `ISRAM` thì sao?**
Thì core reset bộ nhớ chứa chính đoạn code vừa ghi lệnh đó. Chỉ an toàn khi chạy từ
ROM. Em ghi cái này vào tài liệu chứ không để người khác tự phát hiện.

**Nếu boot memory ra khỏi reset sau core thì core đọc rác?**
Không — AXI buộc mọi `VALID` thấp khi slave đang reset, nên ROM không thể assert
`rvalid`; core chỉ **đợi**. Cái bị ảnh hưởng là **liveness**, không phải correctness.
Đây là câu xuyên khối và bài *"Ba khối kể thành một mạch"* trả lời đầy đủ.

**Chân margin với test của macro thì sao?**
Nối theo giá trị databook khuyến nghị: margin ở mức mặc định, retention off, test
off. Đáng ghi vào spec vì cả ba **vô hại trong mô phỏng và chỉ sai trong silicon** —
model hành vi không có chân đó nên không test nào fail được vì chúng.

**Dùng IP này có vấn đề bản quyền không?**
Đây là một câu hỏi mở em ghi trong tài liệu chứ không bỏ qua: repository **không có
file `LICENSE`**. Code công khai trên GitHub nhưng không có giấy phép rõ ràng thì
mặc định là **chưa được cấp quyền**. Với một dự án training nội bộ thì rủi ro thấp,
nhưng nếu QSOC đi xa hơn thì phải xin tác giả một câu xác nhận. Em nêu để thầy quyết.

**Có báo lỗi `WRAP` lại cho tác giả IP không?**
Nên, và em ghi việc đó vào tài liệu như một việc còn phải làm — kèm tham chiếu mục
nào của spec AXI mà nó vi phạm. Đó là cách đúng khi dùng IP mở của người khác.

**Phần khó nhất là gì?**
Không phải RTL. Là nhận ra rằng "46 test pass" không có nghĩa là "đúng", và một
tính năng được khai báo có thể không tồn tại.

---

## Bản ba phút

QSOC không có flash, nên chương trình phải nạp vào RAM sau mỗi lần reset và chạy từ
RAM. Vì thế RAM ở đây không phải chỗ chứa biến — nó chứa chính chương trình.

Khối là một AXI4 SRAM controller lấy từ IP, cộng một macro phụ thuộc công nghệ.
`ISRAM` 64 KiB ở `0x2000_0000` với 4 KiB đầu là debug window nên app dùng 60 KiB;
`DSRAM` 32 KiB ở `0x3000_0000`. Hai cái là **cùng một controller**, khác nhau đúng
một tham số độ sâu macro. Tách ra để stack tràn không đè được code đang chạy.

Chương trình vào bằng **serial bootloader trong ROM** qua `UART0` — frame header,
payload, CRC32, mất 5,4 giây cho ảnh đầy. JTAG là đường thứ hai.

Ba thứ IP không có và em phải xử lý: **không có đường byte enable** nên em thêm
`WSTRB` sang `o_sram_be`; **`AxSIZE` không phải port** nên transfer cố định 32 bit;
và **`WRAP` burst khai là có nhưng cộng tiếp như `INCR`** — 46 test của IP pass hết
vì không test nào dùng `WRAP`, nên em phải ràng buộc mọi master chỉ dùng `INCR` và
`FIXED`.

Đóng góp của em không phải viết lại IP, mà là đọc nó đủ kỹ để biết chỗ nào nó không
làm như nó khai.
